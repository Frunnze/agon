use axum::Json;
use axum::extract::State;
use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use orchestration_api::accounts::{
    ApprovePairingRequest, JoiningDevice, PairingRequestView,
    PairingSessionCreated,
};
use orchestration_api::updates::ChangeTopic;
use orchestration_core::device::Device;
use orchestration_core::identifiers::DeviceId;
use orchestration_security::pairing::{
    PAIRING_SESSION_LIFETIME, PairingCode, PairingSession,
};
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::device_registration::{describe_role, register_device};
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::memberships::{grant_workspace, require_workspace_member};
use crate::pairing_transcripts::require_signed_transcript;
use crate::server::SharedServer;
use crate::stored_state::{JoinOutcome, PairingRecord, StoredState};

const UNKNOWN_SESSION: &str = "the pairing session";

pub async fn start_pairing(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<(StatusCode, Json<PairingSessionCreated>), ServerError> {
    request.caller.require_client()?;
    let caller_id = &request.caller.device_id;
    let created = server.apply(caller_id, |state, now| {
        open_pairing_session(state, caller_id, now)
    })?;
    Ok((StatusCode::CREATED, Json(created)))
}

pub async fn show_pairing_request(
    State(server): State<SharedServer>,
    PathValue(code_text): PathValue<String>,
    request: SignedRequest,
) -> Result<Json<PairingRequestView>, ServerError> {
    request.caller.require_client()?;
    let view = server.read(|state| build_pairing_view(state, &code_text))?;
    Ok(Json(view))
}

pub async fn approve_pairing(
    State(server): State<SharedServer>,
    PathValue(code_text): PathValue<String>,
    request: SignedRequest,
) -> Result<Json<Device>, ServerError> {
    request.caller.require_client()?;
    let approval: ApprovePairingRequest = parse_json_body(&request.body)?;
    let caller_id = &request.caller.device_id;
    let device = server.apply(caller_id, |state, now| {
        approve_join(state, &code_text, caller_id, &approval, now)
    })?;
    Ok(Json(device))
}

pub fn pairing_key(code_text: &str) -> Result<String, ServerError> {
    let code = PairingCode::parse(code_text)
        .map_err(|_| ServerError::NotFound(UNKNOWN_SESSION))?;
    Ok(String::from(code))
}

fn open_pairing_session(
    state: &mut StoredState,
    started_by: &DeviceId,
    now: DateTime<Utc>,
) -> Result<Change<PairingSessionCreated>, ServerError> {
    let session = PairingSession::start(now).map_err(|_| {
        ServerError::Internal("the pairing code could not be generated")
    })?;
    let code_key = String::from(session.code.clone());
    if state.pairing_sessions.contains_key(&code_key) {
        return Err(ServerError::Conflict(
            "the pairing code is already in use, try again".to_owned(),
        ));
    }

    let created = PairingSessionCreated {
        code: session.code.display(),
        started_at: session.started_at,
        expires_at: session.started_at + PAIRING_SESSION_LIFETIME,
    };
    let record = PairingRecord {
        session,
        started_by: started_by.clone(),
        join_id: None,
        approver_commitment: None,
    };
    state.pairing_sessions.insert(code_key, record);
    let event_text = "Started pairing".to_owned();
    Ok(Change::recorded(created, ChangeTopic::Pairing, event_text))
}

fn build_pairing_view(
    state: &StoredState,
    code_text: &str,
) -> Result<PairingRequestView, ServerError> {
    let record = find_pairing(state, &pairing_key(code_text)?)?;
    let joining = record
        .join_id
        .and_then(|join_id| state.joins.get(&join_id))
        .map(|join| JoiningDevice {
            name: join.registration.name.clone(),
            role: join.registration.role,
            kind: join.registration.kind,
            key_kind: join.registration.key_kind,
            signing_public_key: join.registration.signing_public_key.clone(),
            sealing_public_key: join.registration.sealing_public_key.clone(),
            joiner_nonce: join.joiner_nonce.clone(),
            approver_nonce: join.approver_nonce.clone(),
        });
    Ok(PairingRequestView {
        code: record.session.code.display(),
        started_at: record.session.started_at,
        expires_at: record.session.started_at + PAIRING_SESSION_LIFETIME,
        joining,
    })
}

fn approve_join(
    state: &mut StoredState,
    code_text: &str,
    approver: &DeviceId,
    approval: &ApprovePairingRequest,
    now: DateTime<Utc>,
) -> Result<Change<Device>, ServerError> {
    let code_key = pairing_key(code_text)?;
    let record = find_pairing(state, &code_key)?.clone();
    require_session_owner(&record, approver)?;
    require_unexpired(&record, now)?;
    let join_id = record.join_id.ok_or_else(|| {
        ServerError::Conflict("no device has joined yet".to_owned())
    })?;
    let join = state
        .joins
        .get(&join_id)
        .ok_or(ServerError::NotFound("the join request"))?;
    require_signed_transcript(
        state,
        &record,
        join,
        &approval.approval_signature,
    )?;

    let device_id = admit_joined_device(state, join_id, approver, now)?;
    for sealed in &approval.sealed_workspace_keys {
        require_workspace_member(state, approver, sealed.workspace_id)?;
        grant_workspace(
            state,
            &device_id,
            sealed.workspace_id,
            sealed.sealed_key.clone(),
        )?;
    }
    state.pairing_sessions.remove(&code_key);

    let paired_device = state
        .devices
        .get(&device_id)
        .ok_or(ServerError::NotFound("the device"))?
        .clone();
    let event_text = format!(
        "Paired {} as {}",
        paired_device.name,
        describe_role(paired_device.role)
    );
    Ok(Change::recorded(
        paired_device,
        ChangeTopic::Devices,
        event_text,
    ))
}

fn admit_joined_device(
    state: &mut StoredState,
    join_id: Uuid,
    approver: &DeviceId,
    now: DateTime<Utc>,
) -> Result<DeviceId, ServerError> {
    let join = state
        .joins
        .get_mut(&join_id)
        .ok_or(ServerError::NotFound("the join request"))?;
    let device =
        register_device(&join.registration, Some(approver.clone()), now)?;
    let device_id = device.id.clone();
    if state.devices.contains_key(&device_id) {
        return Err(ServerError::Conflict(
            "this device is already paired".to_owned(),
        ));
    }

    join.outcome = JoinOutcome::Approved {
        device_id: device_id.clone(),
    };
    state.devices.insert(device_id.clone(), device);
    Ok(device_id)
}

pub fn find_pairing<'state>(
    state: &'state StoredState,
    code_key: &str,
) -> Result<&'state PairingRecord, ServerError> {
    state
        .pairing_sessions
        .get(code_key)
        .ok_or(ServerError::NotFound(UNKNOWN_SESSION))
}

pub fn find_pairing_mut<'state>(
    state: &'state mut StoredState,
    code_key: &str,
) -> Result<&'state mut PairingRecord, ServerError> {
    state
        .pairing_sessions
        .get_mut(code_key)
        .ok_or(ServerError::NotFound(UNKNOWN_SESSION))
}

pub fn require_session_owner(
    record: &PairingRecord,
    device_id: &DeviceId,
) -> Result<(), ServerError> {
    if record.started_by == *device_id {
        return Ok(());
    }
    Err(ServerError::Forbidden(
        "only the device that showed the code can decide",
    ))
}

pub fn require_unexpired(
    record: &PairingRecord,
    now: DateTime<Utc>,
) -> Result<(), ServerError> {
    if record.session.is_expired(now) {
        return Err(ServerError::Conflict(
            "the pairing session has expired".to_owned(),
        ));
    }
    Ok(())
}

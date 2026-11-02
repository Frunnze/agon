use axum::Json;
use axum::body::Bytes;
use axum::extract::State;
use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use orchestration_api::accounts::{JoinAccepted, JoinRequest, JoinStatus};
use orchestration_api::updates::ChangeTopic;
use orchestration_core::identifiers::{DeviceId, generate_uuid};
use orchestration_security::identity::device_id_for;
use orchestration_security::pairing::{PairingCode, PairingSession};
use uuid::Uuid;

use crate::accounts::build_account_view;
use crate::change::Change;
use crate::device_registration::register_device;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::pairing_transcripts::approver_keys_of;
use crate::server::SharedServer;
use crate::stored_state::{JoinOutcome, JoinRecord, StoredState};

pub async fn join_pairing(
    State(server): State<SharedServer>,
    body: Bytes,
) -> Result<(StatusCode, Json<JoinAccepted>), ServerError> {
    let request: JoinRequest = parse_json_body(&body)?;
    let joining_id = device_id_for(&request.device.signing_public_key);
    let accepted = server
        .apply(&joining_id, |state, now| record_join(state, &request, now))?;
    Ok((StatusCode::CREATED, Json(accepted)))
}

pub async fn show_join_status(
    State(server): State<SharedServer>,
    PathValue(join_id): PathValue<Uuid>,
) -> Result<Json<JoinStatus>, ServerError> {
    let now = server.now();
    let status =
        server.read(|state| describe_join_status(state, join_id, now))?;
    Ok(Json(status))
}

struct OpenedJoin {
    join_id: Uuid,
    session: PairingSession,
    trusted_device_id: DeviceId,
    approver_commitment: Vec<u8>,
}

fn record_join(
    state: &mut StoredState,
    request: &JoinRequest,
    now: DateTime<Utc>,
) -> Result<Change<JoinAccepted>, ServerError> {
    let opened = open_join(state, &request.code, now)?;
    let device = register_device(&request.device, None, now)?;
    if state.devices.contains_key(&device.id) {
        return Err(ServerError::Conflict(
            "this device is already paired".to_owned(),
        ));
    }
    let approver = approver_keys_of(state, &opened.trusted_device_id)?;

    let join = JoinRecord {
        session: opened.session,
        registration: request.device.clone(),
        joiner_nonce: None,
        approver_nonce: None,
        outcome: JoinOutcome::Waiting,
    };
    state.joins.insert(opened.join_id, join);
    let accepted = JoinAccepted {
        join_id: opened.join_id,
        approver_signing_public_key: approver.signing_public_key,
        approver_sealing_public_key: approver.sealing_public_key,
        approver_commitment: opened.approver_commitment,
    };
    let event_text = format!("{} asked to join", request.device.name);
    Ok(Change::recorded(accepted, ChangeTopic::Pairing, event_text))
}

fn open_join(
    state: &mut StoredState,
    code_text: &str,
    now: DateTime<Utc>,
) -> Result<OpenedJoin, ServerError> {
    let code = PairingCode::parse(code_text).map_err(|_| {
        ServerError::Invalid("the pairing code is malformed".to_owned())
    })?;
    let code_key = String::from(code.clone());
    let record = state
        .pairing_sessions
        .get_mut(&code_key)
        .ok_or(ServerError::NotFound("the pairing session"))?;
    record.session.verify_join(&code, now).map_err(|_| {
        ServerError::Conflict("the pairing session has expired".to_owned())
    })?;
    let approver_commitment =
        record.approver_commitment.clone().ok_or_else(|| {
            ServerError::Conflict(
                "the pairing code is not ready yet".to_owned(),
            )
        })?;
    if record.join_id.is_some() {
        return Err(ServerError::Conflict(
            "another device already joined with this code".to_owned(),
        ));
    }

    let join_id = generate_uuid();
    record.join_id = Some(join_id);
    Ok(OpenedJoin {
        join_id,
        session: record.session.clone(),
        trusted_device_id: record.started_by.clone(),
        approver_commitment,
    })
}

fn describe_join_status(
    state: &StoredState,
    join_id: Uuid,
    now: DateTime<Utc>,
) -> Result<JoinStatus, ServerError> {
    let join = state
        .joins
        .get(&join_id)
        .ok_or(ServerError::NotFound("the join request"))?;
    match &join.outcome {
        JoinOutcome::Approved { device_id } => {
            let account = build_account_view(state, device_id)?;
            let approver_nonce = join.approver_nonce.clone().ok_or(
                ServerError::Internal("the approved join has no nonce"),
            )?;
            Ok(JoinStatus::Approved {
                account,
                approver_nonce,
            })
        }
        JoinOutcome::Rejected => Ok(JoinStatus::Rejected),
        JoinOutcome::Waiting if join.session.is_expired(now) => {
            Ok(JoinStatus::Expired)
        }
        JoinOutcome::Waiting => Ok(JoinStatus::Waiting {
            approver_nonce: join.approver_nonce.clone(),
        }),
    }
}

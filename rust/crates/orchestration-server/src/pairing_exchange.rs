use axum::body::Bytes;
use axum::extract::State;
use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use orchestration_api::accounts::{PairingCommitment, PairingNonce};
use orchestration_core::identifiers::DeviceId;
use orchestration_security::pairing::{
    PAIRING_COMMITMENT_LENGTH, PAIRING_NONCE_LENGTH,
    verify_approver_commitment,
};
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::pairing_sessions::{
    find_pairing, find_pairing_mut, pairing_key, require_session_owner,
    require_unexpired,
};
use crate::pairing_transcripts::approver_keys_of;
use crate::server::SharedServer;
use crate::stored_state::{JoinOutcome, JoinRecord, StoredState};

pub async fn commit_pairing(
    State(server): State<SharedServer>,
    PathValue(code_text): PathValue<String>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_client()?;
    let body: PairingCommitment = parse_json_body(&request.body)?;
    let caller_id = &request.caller.device_id;
    server.apply(caller_id, |state, now| {
        record_commitment(state, &code_text, caller_id, body.commitment, now)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

pub async fn reveal_approver_nonce(
    State(server): State<SharedServer>,
    PathValue(code_text): PathValue<String>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_client()?;
    let body: PairingNonce = parse_json_body(&request.body)?;
    let caller_id = &request.caller.device_id;
    server.apply(caller_id, |state, now| {
        record_approver_nonce(state, &code_text, caller_id, body.nonce, now)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

pub async fn receive_joiner_nonce(
    State(server): State<SharedServer>,
    PathValue(join_id): PathValue<Uuid>,
    body: Bytes,
) -> Result<StatusCode, ServerError> {
    let nonce_body: PairingNonce = parse_json_body(&body)?;
    let server_id = server.device_id();
    server.apply(&server_id, |state, now| {
        record_joiner_nonce(state, join_id, nonce_body.nonce, now)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

fn record_commitment(
    state: &mut StoredState,
    code_text: &str,
    caller: &DeviceId,
    commitment: Vec<u8>,
    now: DateTime<Utc>,
) -> Result<Change<()>, ServerError> {
    if commitment.len() != PAIRING_COMMITMENT_LENGTH {
        return Err(ServerError::Invalid(
            "the pairing commitment has the wrong length".to_owned(),
        ));
    }
    let record = find_pairing_mut(state, &pairing_key(code_text)?)?;
    require_session_owner(record, caller)?;
    require_unexpired(record, now)?;
    if record.approver_commitment.is_some() {
        return Err(ServerError::Conflict(
            "the pairing code already has a commitment".to_owned(),
        ));
    }

    record.approver_commitment = Some(commitment);
    Ok(Change::saved_without_record(()))
}

fn record_approver_nonce(
    state: &mut StoredState,
    code_text: &str,
    caller: &DeviceId,
    nonce: Vec<u8>,
    now: DateTime<Utc>,
) -> Result<Change<()>, ServerError> {
    require_nonce_length(&nonce)?;
    let record = find_pairing(state, &pairing_key(code_text)?)?.clone();
    require_session_owner(&record, caller)?;
    require_unexpired(&record, now)?;
    let (Some(join_id), Some(commitment)) =
        (record.join_id, &record.approver_commitment)
    else {
        return Err(ServerError::Conflict(
            "no device has joined yet".to_owned(),
        ));
    };
    let approver = approver_keys_of(state, &record.started_by)?;
    verify_approver_commitment(
        &record.session.code,
        &approver,
        &nonce,
        commitment,
    )
    .map_err(|_| {
        ServerError::Conflict(
            "the nonce does not open the pairing commitment".to_owned(),
        )
    })?;

    let join = find_join_mut(state, join_id)?;
    if join.joiner_nonce.is_none() {
        return Err(ServerError::Conflict(
            "the joining device has not sent its nonce yet".to_owned(),
        ));
    }
    if join.approver_nonce.is_some() {
        return Ok(Change::unchanged(()));
    }
    join.approver_nonce = Some(nonce);
    Ok(Change::saved_without_record(()))
}

fn record_joiner_nonce(
    state: &mut StoredState,
    join_id: Uuid,
    nonce: Vec<u8>,
    now: DateTime<Utc>,
) -> Result<Change<()>, ServerError> {
    require_nonce_length(&nonce)?;
    let join = find_join_mut(state, join_id)?;
    if !matches!(join.outcome, JoinOutcome::Waiting) {
        return Err(ServerError::Conflict(
            "the join request is already decided".to_owned(),
        ));
    }
    if join.session.is_expired(now) {
        return Err(ServerError::Conflict(
            "the pairing session has expired".to_owned(),
        ));
    }
    if join.joiner_nonce.is_some() {
        return Err(ServerError::Conflict(
            "the joining device already sent its nonce".to_owned(),
        ));
    }

    join.joiner_nonce = Some(nonce);
    Ok(Change::saved_without_record(()))
}

fn require_nonce_length(nonce: &[u8]) -> Result<(), ServerError> {
    if nonce.len() == PAIRING_NONCE_LENGTH {
        return Ok(());
    }
    Err(ServerError::Invalid(
        "a pairing nonce has the wrong length".to_owned(),
    ))
}

fn find_join_mut(
    state: &mut StoredState,
    join_id: Uuid,
) -> Result<&mut JoinRecord, ServerError> {
    state
        .joins
        .get_mut(&join_id)
        .ok_or(ServerError::NotFound("the join request"))
}

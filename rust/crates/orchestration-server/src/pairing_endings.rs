use axum::extract::State;
use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use orchestration_api::updates::ChangeTopic;
use orchestration_core::identifiers::DeviceId;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::extractors::PathValue;
use crate::pairing_sessions::{
    find_pairing, pairing_key, require_session_owner, require_unexpired,
};
use crate::server::SharedServer;
use crate::stored_state::{JoinOutcome, StoredState};

pub async fn reject_pairing(
    State(server): State<SharedServer>,
    PathValue(code_text): PathValue<String>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_client()?;
    let caller_id = &request.caller.device_id;
    server.apply(caller_id, |state, _now| {
        reject_join(state, &code_text, caller_id)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

pub async fn cancel_pairing(
    State(server): State<SharedServer>,
    PathValue(code_text): PathValue<String>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_client()?;
    let caller_id = &request.caller.device_id;
    server.apply(caller_id, |state, now| {
        cancel_session(state, &code_text, caller_id, now)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

fn reject_join(
    state: &mut StoredState,
    code_text: &str,
    rejecter: &DeviceId,
) -> Result<Change<()>, ServerError> {
    let code_key = pairing_key(code_text)?;
    require_session_owner(find_pairing(state, &code_key)?, rejecter)?;
    let event_text = match close_session(state, &code_key) {
        Some(joined_name) => format!("Rejected pairing of {joined_name}"),
        None => "Cancelled pairing".to_owned(),
    };
    Ok(Change::recorded((), ChangeTopic::Pairing, event_text))
}

fn cancel_session(
    state: &mut StoredState,
    code_text: &str,
    canceller: &DeviceId,
    now: DateTime<Utc>,
) -> Result<Change<()>, ServerError> {
    let code_key = pairing_key(code_text)?;
    let record = find_pairing(state, &code_key)?;
    require_session_owner(record, canceller)?;
    require_unexpired(record, now)?;
    let event_text = match close_session(state, &code_key) {
        Some(joined_name) => format!("Cancelled pairing of {joined_name}"),
        None => "Cancelled pairing".to_owned(),
    };
    Ok(Change::recorded((), ChangeTopic::Pairing, event_text))
}

fn close_session(state: &mut StoredState, code_key: &str) -> Option<String> {
    let record = state.pairing_sessions.remove(code_key)?;
    let join_id = record.join_id?;
    let join = state.joins.get_mut(&join_id)?;
    join.outcome = JoinOutcome::Rejected;
    Some(join.registration.name.clone())
}

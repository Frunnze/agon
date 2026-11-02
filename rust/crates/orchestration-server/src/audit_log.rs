use axum::Json;
use axum::extract::State;
use chrono::{DateTime, Utc};
use orchestration_api::updates::{AuditEntryView, AuditView};
use orchestration_core::identifiers::DeviceId;
use orchestration_security::audit::{
    AuditEntry, GENESIS_HASH, SignerKeys, append_entry, verify_chain,
};
use orchestration_security::identity::DeviceIdentity;

use crate::authentication::SignedRequest;
use crate::error::ServerError;
use crate::server::SharedServer;
use crate::stored_state::StoredState;

const ACTING_DEVICE_SEPARATOR: char = ' ';

pub async fn show_audit_log(
    State(server): State<SharedServer>,
    _request: SignedRequest,
) -> Result<Json<AuditView>, ServerError> {
    let server_identity = server.public_identity();
    let audit_view = server.read(|state| {
        let mut signer_keys = state.server_group.audit_signers.clone();
        signer_keys.insert(
            server_identity.device_id.clone(),
            server_identity.signing_public_key.clone(),
        );
        Ok(build_audit_view(&state.audit_log, &signer_keys))
    })?;
    Ok(Json(audit_view))
}

#[derive(Debug)]
pub struct AuditEvent<'event> {
    pub acting_device: &'event DeviceId,
    pub text: &'event str,
    pub detail: Option<String>,
}

pub fn append_audit_event(
    state: &mut StoredState,
    server_identity: &DeviceIdentity,
    audit_event: &AuditEvent<'_>,
    now: DateTime<Utc>,
) {
    let event = format!(
        "{}{ACTING_DEVICE_SEPARATOR}{}",
        audit_event.acting_device.0, audit_event.text
    );
    let detail = audit_event.detail.clone();
    let entry =
        append_entry(&state.audit_log, server_identity, event, detail, now);
    state.audit_log.push(entry);
}

fn build_audit_view(
    chain: &[AuditEntry],
    signer_keys: &SignerKeys,
) -> AuditView {
    let intact = verify_chain(chain, signer_keys).is_ok();
    let entries = chain.iter().map(view_entry).collect();
    let head_hash = chain
        .last()
        .map_or_else(|| GENESIS_HASH.to_owned(), |entry| entry.hash.clone());
    AuditView {
        entries,
        entry_count: chain.len() as u64,
        head_hash,
        intact,
    }
}

fn view_entry(entry: &AuditEntry) -> AuditEntryView {
    let (acting_device, event_text) = entry
        .event
        .split_once(ACTING_DEVICE_SEPARATOR)
        .unwrap_or((entry.device_id.0.as_str(), entry.event.as_str()));
    AuditEntryView {
        index: entry.index as u64,
        at: entry.at,
        device_id: DeviceId(acting_device.to_owned()),
        event: event_text.to_owned(),
        detail: entry.detail.clone(),
        previous_hash: entry.previous_hash.clone(),
        hash: entry.hash.clone(),
    }
}

use axum::Json;
use axum::extract::State;
use orchestration_api::accounts::{RevokeDeviceRequest, revocation_statement};
use orchestration_api::updates::ChangeTopic;
use orchestration_core::device::Device;
use orchestration_core::identifiers::DeviceId;
use orchestration_security::identity::verify_signature;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::device_registration::signing_key_of;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::request_ledger::Presence;
use crate::server::SharedServer;
use crate::server_group_changes::remove_revoked_member;
use crate::stored_state::StoredState;

pub async fn list_devices(
    State(server): State<SharedServer>,
    _request: SignedRequest,
) -> Result<Json<Vec<Device>>, ServerError> {
    let presence = server.presence_snapshot()?;
    let devices = server
        .read(|state| Ok(list_devices_with_presence(state, &presence)))?;
    Ok(Json(devices))
}

pub async fn revoke_device(
    State(server): State<SharedServer>,
    PathValue(device_text): PathValue<String>,
    request: SignedRequest,
) -> Result<Json<Device>, ServerError> {
    request.caller.require_client()?;
    let revoke_request: RevokeDeviceRequest = parse_json_body(&request.body)?;
    let target_id = DeviceId(device_text);
    let caller_id = &request.caller.device_id;
    let revoked = server.apply(caller_id, |state, _now| {
        revoke(state, caller_id, &target_id, &revoke_request)
    })?;
    Ok(Json(revoked))
}

pub fn list_devices_with_presence(
    state: &StoredState,
    presence: &Presence,
) -> Vec<Device> {
    state
        .devices
        .values()
        .map(|device| apply_presence(device, presence))
        .collect()
}

fn apply_presence(device: &Device, presence: &Presence) -> Device {
    let last_seen = presence
        .get(&device.id)
        .map_or(device.last_seen, |seen_at| (*seen_at).max(device.last_seen));
    Device {
        last_seen,
        ..device.clone()
    }
}

fn revoke(
    state: &mut StoredState,
    revoker_id: &DeviceId,
    target_id: &DeviceId,
    revoke_request: &RevokeDeviceRequest,
) -> Result<Change<Device>, ServerError> {
    if revoker_id == target_id {
        return Err(ServerError::Forbidden("a device cannot revoke itself"));
    }
    let revoker_key = signing_key_of(state, revoker_id)
        .ok_or(ServerError::Forbidden("the revoking device is not trusted"))?;
    let target = state
        .devices
        .get_mut(target_id)
        .ok_or(ServerError::NotFound("the device"))?;
    if target.revoked {
        return Err(ServerError::Conflict(
            "the device is already revoked".to_owned(),
        ));
    }
    verify_signature(
        &revoker_key,
        &revocation_statement(target_id),
        &revoke_request.approval_signature,
    )
    .map_err(|_| {
        ServerError::Forbidden("the revocation approval does not verify")
    })?;

    target.revoked = true;
    let revoked = target.clone();
    state.workspace_keys.remove(target_id);
    state.runners.remove(target_id);
    remove_revoked_member(state, target_id);
    let event_text = format!("Revoked {}", revoked.name);
    Ok(Change::recorded(revoked, ChangeTopic::Devices, event_text))
}

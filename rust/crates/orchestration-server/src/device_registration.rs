use chrono::{DateTime, Utc};
use orchestration_api::accounts::DeviceRegistration;
use orchestration_core::device::{Device, DeviceRole};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::naming::validate_name;
use orchestration_security::identity::{KEY_LENGTH, device_id_for};

use crate::error::ServerError;
use crate::stored_state::StoredState;

pub fn register_device(
    registration: &DeviceRegistration,
    approved_by: Option<DeviceId>,
    now: DateTime<Utc>,
) -> Result<Device, ServerError> {
    validate_name(&registration.name)?;
    let has_valid_keys = registration.signing_public_key.len() == KEY_LENGTH
        && registration.sealing_public_key.len() == KEY_LENGTH;
    if !has_valid_keys {
        return Err(ServerError::Invalid(
            "a device key has the wrong length".to_owned(),
        ));
    }

    Ok(Device {
        peer_address: None,
        id: device_id_for(&registration.signing_public_key),
        name: registration.name.clone(),
        role: registration.role,
        kind: registration.kind,
        key_kind: registration.key_kind,
        signing_public_key: registration.signing_public_key.clone(),
        sealing_public_key: registration.sealing_public_key.clone(),
        workspaces: Vec::new(),
        paired_at: now,
        approved_by,
        last_seen: now,
        revoked: false,
    })
}

pub fn name_device(state: &StoredState, device_id: &DeviceId) -> String {
    state
        .devices
        .get(device_id)
        .map_or_else(|| device_id.0.clone(), |device| device.name.clone())
}

pub fn describe_role(role: DeviceRole) -> &'static str {
    match role {
        DeviceRole::Client => "a client",
        DeviceRole::Runner => "a runner",
        DeviceRole::ClientAndRunner => "a client and runner",
    }
}

pub fn signing_key_of(
    state: &StoredState,
    device_id: &DeviceId,
) -> Option<Vec<u8>> {
    state
        .devices
        .get(device_id)
        .filter(|device| !device.revoked)
        .map(|device| device.signing_public_key.clone())
}

use orchestration_api::accounts::SealedWorkspaceKey;
use orchestration_core::identifiers::{DeviceId, WorkspaceId};

use crate::error::ServerError;
use crate::stored_state::StoredState;

pub fn is_workspace_member(
    state: &StoredState,
    device_id: &DeviceId,
    workspace_id: WorkspaceId,
) -> bool {
    state
        .devices
        .get(device_id)
        .is_some_and(|device| device.workspaces.contains(&workspace_id))
}

pub fn require_workspace_member(
    state: &StoredState,
    device_id: &DeviceId,
    workspace_id: WorkspaceId,
) -> Result<(), ServerError> {
    if is_workspace_member(state, device_id, workspace_id) {
        return Ok(());
    }
    Err(ServerError::Forbidden(
        "the device is not in that workspace",
    ))
}

pub fn grant_workspace(
    state: &mut StoredState,
    device_id: &DeviceId,
    workspace_id: WorkspaceId,
    sealed_key: Vec<u8>,
) -> Result<(), ServerError> {
    if !state.workspaces.contains_key(&workspace_id) {
        return Err(ServerError::NotFound("the workspace"));
    }
    let device = state
        .devices
        .get_mut(device_id)
        .ok_or(ServerError::NotFound("the device"))?;
    if !device.workspaces.contains(&workspace_id) {
        device.workspaces.push(workspace_id);
    }

    let sealed_keys =
        state.workspace_keys.entry(device_id.clone()).or_default();
    sealed_keys.retain(|sealed| sealed.workspace_id != workspace_id);
    sealed_keys.push(SealedWorkspaceKey {
        workspace_id,
        sealed_key,
    });
    Ok(())
}

pub fn withdraw_workspace(
    state: &mut StoredState,
    device_id: &DeviceId,
    workspace_id: WorkspaceId,
) {
    if let Some(device) = state.devices.get_mut(device_id) {
        device
            .workspaces
            .retain(|member_of| *member_of != workspace_id);
    }
    if let Some(sealed_keys) = state.workspace_keys.get_mut(device_id) {
        sealed_keys.retain(|sealed| sealed.workspace_id != workspace_id);
    }
}

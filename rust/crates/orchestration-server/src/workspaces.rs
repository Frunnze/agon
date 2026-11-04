use axum::Json;
use axum::extract::State;
use axum::http::StatusCode;
use orchestration_api::catalog::{
    AddWorkspaceDeviceRequest, CreateWorkspaceRequest,
};
use orchestration_api::updates::ChangeTopic;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::Device;
use orchestration_core::identifiers::{DeviceId, WorkspaceId};
use orchestration_core::naming::validate_name;
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::workspace::Workspace;
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::device_registration::name_device;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::memberships::{
    grant_workspace, is_workspace_member, require_workspace_member,
    withdraw_workspace,
};
use crate::server::SharedServer;
use crate::stored_state::StoredState;

pub async fn list_workspaces(
    State(server): State<SharedServer>,
    _request: SignedRequest,
) -> Result<Json<Vec<Workspace>>, ServerError> {
    let workspaces = server
        .read(|state| Ok(state.workspaces.values().cloned().collect()))?;
    Ok(Json(workspaces))
}

pub async fn create_workspace(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<(StatusCode, Json<Workspace>), ServerError> {
    request.caller.require_client()?;
    let create_request: CreateWorkspaceRequest =
        parse_json_body(&request.body)?;
    let public_address = server.settings().public_address.clone();
    let caller_id = &request.caller.device_id;
    let workspace = server.apply(caller_id, |state, _now| {
        open_workspace(state, caller_id, &create_request, &public_address)
    })?;
    Ok((StatusCode::CREATED, Json(workspace)))
}

pub async fn add_workspace_device(
    State(server): State<SharedServer>,
    PathValue(workspace_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Device>, ServerError> {
    request.caller.require_client()?;
    let add_request: AddWorkspaceDeviceRequest =
        parse_json_body(&request.body)?;
    let workspace_id = WorkspaceId(workspace_uuid);
    let caller_id = &request.caller.device_id;
    let device = server.apply(caller_id, |state, _now| {
        add_member(state, caller_id, workspace_id, &add_request)
    })?;
    Ok(Json(device))
}

pub async fn remove_workspace_device(
    State(server): State<SharedServer>,
    PathValue((workspace_uuid, device_text)): PathValue<(Uuid, String)>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_client()?;
    let workspace_id = WorkspaceId(workspace_uuid);
    let member_id = DeviceId(device_text);
    let caller_id = &request.caller.device_id;
    server.apply(caller_id, |state, _now| {
        remove_member(state, caller_id, workspace_id, &member_id)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

fn open_workspace(
    state: &mut StoredState,
    creator_id: &DeviceId,
    request: &CreateWorkspaceRequest,
    public_address: &str,
) -> Result<Change<Workspace>, ServerError> {
    validate_name(&request.name)?;
    if state.workspaces.contains_key(&request.workspace_id) {
        return Err(ServerError::Conflict(
            "the workspace already exists".to_owned(),
        ));
    }
    let workspace = Workspace {
        id: request.workspace_id,
        name: request.name.clone(),
        app_server_address: public_address.to_owned(),
        approval_policy: ApprovalPolicy::default(),
        protected_files: ProtectedFiles::default(),
    };
    state.workspaces.insert(workspace.id, workspace.clone());
    grant_workspace(
        state,
        creator_id,
        workspace.id,
        request.sealed_workspace_key.clone(),
    )?;
    let event_text = format!("Created workspace {}", workspace.name);
    Ok(Change::recorded(
        workspace,
        ChangeTopic::Workspaces,
        event_text,
    ))
}

fn add_member(
    state: &mut StoredState,
    caller_id: &DeviceId,
    workspace_id: WorkspaceId,
    request: &AddWorkspaceDeviceRequest,
) -> Result<Change<Device>, ServerError> {
    require_workspace_member(state, caller_id, workspace_id)?;
    let device = state
        .devices
        .get(&request.device_id)
        .ok_or(ServerError::NotFound("the device"))?;
    if device.revoked {
        return Err(ServerError::Conflict("the device is revoked".to_owned()));
    }
    if is_workspace_member(state, &request.device_id, workspace_id) {
        return Err(ServerError::Conflict(
            "the device is already in the workspace".to_owned(),
        ));
    }

    grant_workspace(
        state,
        &request.device_id,
        workspace_id,
        request.sealed_workspace_key.clone(),
    )?;
    let member = state
        .devices
        .get(&request.device_id)
        .ok_or(ServerError::NotFound("the device"))?
        .clone();
    let event_text = format!(
        "Added {} to workspace {}",
        member.name,
        name_workspace(state, workspace_id)
    );
    Ok(Change::recorded(
        member,
        ChangeTopic::Workspaces,
        event_text,
    ))
}

fn remove_member(
    state: &mut StoredState,
    caller_id: &DeviceId,
    workspace_id: WorkspaceId,
    member_id: &DeviceId,
) -> Result<Change<()>, ServerError> {
    require_workspace_member(state, caller_id, workspace_id)?;
    if !is_workspace_member(state, member_id, workspace_id) {
        return Err(ServerError::NotFound("the workspace member"));
    }
    withdraw_workspace(state, member_id, workspace_id);
    let event_text = format!(
        "Removed {} from workspace {}",
        name_device(state, member_id),
        name_workspace(state, workspace_id)
    );
    Ok(Change::recorded((), ChangeTopic::Workspaces, event_text))
}

fn name_workspace(state: &StoredState, workspace_id: WorkspaceId) -> String {
    state.workspaces.get(&workspace_id).map_or_else(
        || workspace_id.0.to_string(),
        |workspace| workspace.name.clone(),
    )
}

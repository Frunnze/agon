use axum::Json;
use axum::extract::State;
use orchestration_api::catalog::SetProtectedFilesRequest;
use orchestration_api::updates::ChangeTopic;
use orchestration_core::identifiers::{DeviceId, WorkspaceId};
use orchestration_core::protected_files::{
    ProtectedFiles, validate_protected_files,
};
use orchestration_core::workspace::Workspace;
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::memberships::require_workspace_member;
use crate::server::SharedServer;
use crate::stored_state::StoredState;

pub async fn set_protected_files(
    State(server): State<SharedServer>,
    PathValue(workspace_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Workspace>, ServerError> {
    request.caller.require_client()?;
    let set_request: SetProtectedFilesRequest =
        parse_json_body(&request.body)?;
    validate_protected_files(&set_request.protected_files)?;
    let workspace_id = WorkspaceId(workspace_uuid);
    let caller_id = &request.caller.device_id;
    let workspace = server.apply(caller_id, |state, _now| {
        store_protected_files(
            state,
            caller_id,
            workspace_id,
            &set_request.protected_files,
        )
    })?;
    Ok(Json(workspace))
}

pub fn find_workspace_protected_files(
    state: &StoredState,
    workspace_id: WorkspaceId,
) -> Result<ProtectedFiles, ServerError> {
    let workspace = state
        .workspaces
        .get(&workspace_id)
        .ok_or(ServerError::NotFound("the workspace"))?;
    Ok(workspace.protected_files.clone())
}

fn store_protected_files(
    state: &mut StoredState,
    caller_id: &DeviceId,
    workspace_id: WorkspaceId,
    protected_files: &ProtectedFiles,
) -> Result<Change<Workspace>, ServerError> {
    require_workspace_member(state, caller_id, workspace_id)?;
    let workspace = state
        .workspaces
        .get_mut(&workspace_id)
        .ok_or(ServerError::NotFound("the workspace"))?;
    workspace.protected_files = protected_files.clone();

    let event_text = format!(
        "Changed the files agents can't read in workspace {} to {} patterns",
        workspace.name,
        protected_files.patterns.len()
    );
    Ok(Change::recorded(
        workspace.clone(),
        ChangeTopic::Workspaces,
        event_text,
    ))
}

use axum::Json;
use axum::extract::State;
use orchestration_api::catalog::ChangeWorkspaceApprovalPolicyRequest;
use orchestration_api::updates::ChangeTopic;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::identifiers::{DeviceId, WorkspaceId};
use orchestration_core::workspace::Workspace;
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::memberships::require_workspace_member;
use crate::server::SharedServer;
use crate::stored_state::StoredState;

const AUTO_TEXT: &str = "Auto";
const ASK_ME_TEXT: &str = "Ask me";

pub async fn change_workspace_approval_policy(
    State(server): State<SharedServer>,
    PathValue(workspace_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Workspace>, ServerError> {
    request.caller.require_client()?;
    let change_request: ChangeWorkspaceApprovalPolicyRequest =
        parse_json_body(&request.body)?;
    let workspace_id = WorkspaceId(workspace_uuid);
    let caller_id = &request.caller.device_id;
    let workspace = server.apply(caller_id, |state, _now| {
        store_approval_policy(
            state,
            caller_id,
            workspace_id,
            change_request.approval_policy,
        )
    })?;
    Ok(Json(workspace))
}

pub fn find_workspace_approval_policy(
    state: &StoredState,
    workspace_id: WorkspaceId,
) -> Result<ApprovalPolicy, ServerError> {
    let workspace = state
        .workspaces
        .get(&workspace_id)
        .ok_or(ServerError::NotFound("the workspace"))?;
    Ok(workspace.approval_policy)
}

fn store_approval_policy(
    state: &mut StoredState,
    caller_id: &DeviceId,
    workspace_id: WorkspaceId,
    approval_policy: ApprovalPolicy,
) -> Result<Change<Workspace>, ServerError> {
    require_workspace_member(state, caller_id, workspace_id)?;
    let workspace = state
        .workspaces
        .get_mut(&workspace_id)
        .ok_or(ServerError::NotFound("the workspace"))?;
    workspace.approval_policy = approval_policy;

    let event_text = format!(
        "Set commands and pushes in workspace {} to {}",
        workspace.name,
        name_approval_policy(approval_policy)
    );
    Ok(Change::recorded(
        workspace.clone(),
        ChangeTopic::Workspaces,
        event_text,
    ))
}

const fn name_approval_policy(
    approval_policy: ApprovalPolicy,
) -> &'static str {
    match approval_policy {
        ApprovalPolicy::NeverAsk => AUTO_TEXT,
        ApprovalPolicy::AskBeforeRiskyActions => ASK_ME_TEXT,
    }
}

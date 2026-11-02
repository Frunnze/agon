use axum::extract::State;
use axum::http::StatusCode;
use orchestration_api::updates::ChangeTopic;
use orchestration_core::approval::{ApprovalAction, ApprovalRequest};
use orchestration_core::identifiers::WorkflowId;
use orchestration_core::task::{Task, TaskDoer};
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::events::append_notification;
use crate::extractors::PathValue;
use crate::server::SharedServer;
use crate::stored_state::StoredState;

pub async fn delete_workflow(
    State(server): State<SharedServer>,
    PathValue(workflow_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_client()?;
    let workflow_id = WorkflowId(workflow_uuid);
    let caller_id = &request.caller.device_id;
    server
        .apply(caller_id, |state, _now| drop_workflow(state, workflow_id))?;
    Ok(StatusCode::NO_CONTENT)
}

fn drop_workflow(
    state: &mut StoredState,
    workflow_id: WorkflowId,
) -> Result<Change<()>, ServerError> {
    let workflow_name = state
        .workflows
        .get(&workflow_id)
        .ok_or(ServerError::NotFound("the workflow"))?
        .current
        .name
        .clone();
    let is_used = state
        .tasks
        .values()
        .any(|task| uses_workflow(task, workflow_id));
    if is_used {
        return Err(ServerError::Conflict(format!(
            "workflow {workflow_name} is still used by a task or job"
        )));
    }

    state.workflows.remove(&workflow_id);
    state
        .approvals
        .retain(|_, approval| !asks_to_sign(approval, workflow_id));
    append_notification(state, ChangeTopic::Approvals);
    let event_text = format!("Deleted workflow {workflow_name}");
    Ok(Change::recorded((), ChangeTopic::Workflows, event_text))
}

fn uses_workflow(task: &Task, workflow_id: WorkflowId) -> bool {
    match &task.doer {
        TaskDoer::Workflow {
            workflow_id: used_workflow_id,
        } => *used_workflow_id == workflow_id,
        TaskDoer::OneAgent { .. } => false,
    }
}

fn asks_to_sign(approval: &ApprovalRequest, workflow_id: WorkflowId) -> bool {
    match &approval.action {
        ApprovalAction::SignWorkflow {
            workflow_id: signed_workflow_id,
        } => *signed_workflow_id == workflow_id,
        _ => false,
    }
}

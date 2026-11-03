use std::collections::BTreeSet;

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
use crate::scope_cleanup::is_seen_in_no_workspace;
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
    if is_used_by_any_task(state, workflow_id) {
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

pub fn remove_workflows_seen_in_no_workspace(state: &mut StoredState) {
    let unseen_workflow_ids: BTreeSet<WorkflowId> = state
        .workflows
        .values()
        .map(|record| &record.current)
        .filter(|workflow| {
            is_seen_in_no_workspace(state, &workflow.availability)
        })
        .filter(|workflow| !is_used_by_any_task(state, workflow.id))
        .map(|workflow| workflow.id)
        .collect();

    state
        .workflows
        .retain(|workflow_id, _| !unseen_workflow_ids.contains(workflow_id));
    state.approvals.retain(|_, approval| {
        let is_signing_unseen = unseen_workflow_ids
            .iter()
            .any(|workflow_id| asks_to_sign(approval, *workflow_id));
        !is_signing_unseen
    });
}

fn is_used_by_any_task(state: &StoredState, workflow_id: WorkflowId) -> bool {
    state
        .tasks
        .values()
        .any(|task| uses_workflow(task, workflow_id))
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

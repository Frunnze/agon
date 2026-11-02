use std::collections::BTreeSet;

use axum::extract::State;
use axum::http::StatusCode;
use orchestration_api::updates::ChangeTopic;
use orchestration_core::identifiers::{DeviceId, TaskId};
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::events::append_notification;
use crate::extractors::PathValue;
use crate::server::SharedServer;
use crate::stored_state::StoredState;
use crate::tasks::{describe_task_kind, require_task_access};
use crate::work_removal::{has_unfinished_run, remove_tasks_with_runs};

pub async fn delete_task(
    State(server): State<SharedServer>,
    PathValue(task_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_client()?;
    let task_id = TaskId(task_uuid);
    let caller_id = &request.caller.device_id;
    server.apply(caller_id, |state, _now| {
        drop_task(state, caller_id, task_id)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

fn drop_task(
    state: &mut StoredState,
    caller_id: &DeviceId,
    task_id: TaskId,
) -> Result<Change<()>, ServerError> {
    let task = state
        .tasks
        .get(&task_id)
        .ok_or(ServerError::NotFound("the task"))?
        .clone();
    require_task_access(state, caller_id, &task)?;
    let kind = describe_task_kind(&task);
    let task_ids = BTreeSet::from([task_id]);
    if has_unfinished_run(state, &task_ids) {
        return Err(ServerError::Conflict(format!(
            "the {kind} is running; cancel its run first"
        )));
    }

    remove_tasks_with_runs(state, &task_ids);
    append_notification(state, ChangeTopic::Approvals);
    let event_text = format!("Deleted {kind} {}", task.title);
    Ok(Change::recorded((), ChangeTopic::Tasks, event_text))
}

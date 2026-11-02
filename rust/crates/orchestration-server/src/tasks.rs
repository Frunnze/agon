use axum::Json;
use axum::extract::State;
use chrono::{DateTime, Utc};
use orchestration_api::updates::ChangeTopic;
use orchestration_api::work::{
    SaveTaskRequest, TaskSaved, TaskStart, UpdateTaskRequest,
};
use orchestration_core::identifiers::{DeviceId, TaskId};
use orchestration_core::schedule_rules::next_run_after;
use orchestration_core::scope_rules::workspace_scope_includes;
use orchestration_core::task::{Task, TaskDoer, TaskStatus};
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::memberships::require_workspace_member;
use crate::run_starts::{describe_run_detail, start_run};
use crate::server::SharedServer;
use crate::stored_state::StoredState;
use crate::task_places::find_task_workspace;

pub async fn list_tasks(
    State(server): State<SharedServer>,
    _request: SignedRequest,
) -> Result<Json<Vec<Task>>, ServerError> {
    let tasks =
        server.read(|state| Ok(state.tasks.values().cloned().collect()))?;
    Ok(Json(tasks))
}

pub async fn save_task(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<Json<TaskSaved>, ServerError> {
    request.caller.require_client()?;
    let save_request: SaveTaskRequest = parse_json_body(&request.body)?;
    let caller_id = &request.caller.device_id;
    let saved = server.apply(caller_id, |state, now| {
        store_task(state, caller_id, &save_request, now)
    })?;
    Ok(Json(saved))
}

pub async fn update_task(
    State(server): State<SharedServer>,
    PathValue(task_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Task>, ServerError> {
    request.caller.require_client()?;
    let update_request: UpdateTaskRequest = parse_json_body(&request.body)?;
    let task_id = TaskId(task_uuid);
    let caller_id = &request.caller.device_id;
    let task = server.apply(caller_id, |state, now| {
        replace_task(state, caller_id, task_id, &update_request.task, now)
    })?;
    Ok(Json(task))
}

pub fn require_task_access(
    state: &StoredState,
    device_id: &DeviceId,
    task: &Task,
) -> Result<(), ServerError> {
    let workspace_id = find_task_workspace(state, task)?;
    require_workspace_member(state, device_id, workspace_id)
}

pub fn describe_task_kind(task: &Task) -> &'static str {
    if task.schedule.is_some() {
        return "job";
    }
    "task"
}

fn store_task(
    state: &mut StoredState,
    caller_id: &DeviceId,
    request: &SaveTaskRequest,
    now: DateTime<Utc>,
) -> Result<Change<TaskSaved>, ServerError> {
    let task = &request.task;
    check_task(state, caller_id, task, now)?;
    let status = state
        .tasks
        .get(&task.id)
        .map_or(TaskStatus::ToDo, |existing| existing.status);
    let stored_task = Task {
        status,
        ..task.clone()
    };
    state.tasks.insert(task.id, stored_task);

    let run = match request.start {
        TaskStart::Now => Some(start_run(state, task.id, caller_id, now)?),
        TaskStart::Later => None,
    };
    let saved_task = state
        .tasks
        .get(&task.id)
        .ok_or(ServerError::NotFound("the task"))?
        .clone();
    let kind = describe_task_kind(task);
    let verb = if run.is_some() {
        "Saved and started"
    } else {
        "Saved"
    };
    let event_text = format!("{verb} {kind} {}", task.title);
    let detail = run.as_ref().map(|run| describe_run_detail(state, run));
    let saved = TaskSaved {
        task: saved_task,
        run,
    };
    let change = Change::recorded(saved, ChangeTopic::Tasks, event_text);
    Ok(match detail {
        Some(detail) => change.with_detail(detail),
        None => change,
    })
}

fn replace_task(
    state: &mut StoredState,
    caller_id: &DeviceId,
    task_id: TaskId,
    task: &Task,
    now: DateTime<Utc>,
) -> Result<Change<Task>, ServerError> {
    let existing = state
        .tasks
        .get(&task_id)
        .ok_or(ServerError::NotFound("the task"))?;
    require_task_access(state, caller_id, existing)?;
    if task.id != task_id {
        return Err(ServerError::Invalid(
            "the task id does not match the address".to_owned(),
        ));
    }
    check_task(state, caller_id, task, now)?;

    let replaced = Task {
        status: existing.status,
        created_at: existing.created_at,
        ..task.clone()
    };
    state.tasks.insert(task_id, replaced.clone());
    let kind = describe_task_kind(&replaced);
    let event_text = format!("Changed {kind} {}", replaced.title);
    Ok(Change::recorded(replaced, ChangeTopic::Tasks, event_text))
}

fn check_task(
    state: &StoredState,
    caller_id: &DeviceId,
    task: &Task,
    now: DateTime<Utc>,
) -> Result<(), ServerError> {
    require_task_access(state, caller_id, task)?;
    if let Some(schedule) = &task.schedule {
        next_run_after(schedule, now)?;
    }
    let TaskDoer::Workflow { workflow_id } = &task.doer else {
        return Ok(());
    };

    let record = state
        .workflows
        .get(workflow_id)
        .ok_or(ServerError::NotFound("the workflow"))?;
    let workspace_id = find_task_workspace(state, task)?;
    let is_available =
        workspace_scope_includes(&record.current.availability, workspace_id);
    if !is_available {
        return Err(ServerError::Invalid(format!(
            "workflow {} is not available in this workspace",
            record.current.name
        )));
    }
    Ok(())
}

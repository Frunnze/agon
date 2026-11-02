use axum::Json;
use axum::extract::State;
use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use orchestration_api::updates::ChangeTopic;
use orchestration_api::work::SendChatMessageRequest;
use orchestration_core::identifiers::{DeviceId, RunId, TaskId};
use orchestration_core::run::Run;
use uuid::Uuid;

use crate::authentication::{AuthenticatedDevice, SignedRequest};
use crate::change::Change;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::run_changes::{cancel_run_record, retry_run_record};
use crate::run_starts::{
    describe_run, describe_run_detail, start_run, sync_task_status,
};
use crate::server::SharedServer;
use crate::stored_state::{RunRecord, StoredState};
use crate::tasks::require_task_access;

const UNKNOWN_RUN: &str = "the run";

pub async fn list_runs(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<Json<Vec<Run>>, ServerError> {
    let caller = &request.caller;
    let runs = server.read(|state| Ok(visible_runs(state, caller, None)))?;
    Ok(Json(runs))
}

pub async fn list_task_runs(
    State(server): State<SharedServer>,
    PathValue(task_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Vec<Run>>, ServerError> {
    let caller = &request.caller;
    let task_id = Some(TaskId(task_uuid));
    let runs =
        server.read(|state| Ok(visible_runs(state, caller, task_id)))?;
    Ok(Json(runs))
}

pub async fn show_run(
    State(server): State<SharedServer>,
    PathValue(run_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Run>, ServerError> {
    let caller = &request.caller;
    let run_id = RunId(run_uuid);
    let run = server.read(|state| read_visible_run(state, caller, run_id))?;
    Ok(Json(run))
}

pub async fn start_task_run(
    State(server): State<SharedServer>,
    PathValue(task_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<(StatusCode, Json<Run>), ServerError> {
    request.caller.require_client()?;
    let task_id = TaskId(task_uuid);
    let caller_id = &request.caller.device_id;
    let run = server.apply(caller_id, |state, now| {
        start_requested_run(state, task_id, caller_id, now)
    })?;
    Ok((StatusCode::CREATED, Json(run)))
}

pub async fn cancel_run(
    State(server): State<SharedServer>,
    PathValue(run_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Run>, ServerError> {
    request.caller.require_client()?;
    let run_id = RunId(run_uuid);
    let run = server.apply(&request.caller.device_id, |state, now| {
        cancel_stored_run(state, run_id, now)
    })?;
    Ok(Json(run))
}

pub async fn retry_run(
    State(server): State<SharedServer>,
    PathValue(run_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Run>, ServerError> {
    request.caller.require_client()?;
    let run_id = RunId(run_uuid);
    let run = server.apply(&request.caller.device_id, |state, _now| {
        retry_stored_run(state, run_id)
    })?;
    Ok(Json(run))
}

pub async fn send_chat_message(
    State(server): State<SharedServer>,
    PathValue(run_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Run>, ServerError> {
    request.caller.require_client()?;
    let message_request: SendChatMessageRequest =
        parse_json_body(&request.body)?;
    let run_id = RunId(run_uuid);
    let run = server.apply(&request.caller.device_id, |state, _now| {
        append_chat_message(state, run_id, &message_request)
    })?;
    Ok(Json(run))
}

pub fn find_run(
    state: &StoredState,
    run_id: RunId,
) -> Result<&RunRecord, ServerError> {
    state
        .runs
        .get(&run_id)
        .ok_or(ServerError::NotFound(UNKNOWN_RUN))
}

pub fn holds_step(run: &Run, runner_id: &DeviceId) -> bool {
    run.steps
        .iter()
        .any(|step| step.runner.as_ref() == Some(runner_id))
}

fn read_visible_run(
    state: &StoredState,
    caller: &AuthenticatedDevice,
    run_id: RunId,
) -> Result<Run, ServerError> {
    let record = find_run(state, run_id)?;
    if !can_see_run(caller, record) {
        return Err(ServerError::Forbidden(
            "the run belongs to another runner",
        ));
    }
    Ok(record.run.clone())
}

fn can_see_run(caller: &AuthenticatedDevice, record: &RunRecord) -> bool {
    caller.is_client() || holds_step(&record.run, &caller.device_id)
}

fn visible_runs(
    state: &StoredState,
    caller: &AuthenticatedDevice,
    task_id: Option<TaskId>,
) -> Vec<Run> {
    let mut runs: Vec<Run> = state
        .runs
        .values()
        .filter(|record| can_see_run(caller, record))
        .filter(|record| task_id.is_none_or(|id| record.run.task_id == id))
        .map(|record| record.run.clone())
        .collect();
    runs.sort_by_key(|run| (run.started_at, run.id));
    runs
}

fn start_requested_run(
    state: &mut StoredState,
    task_id: TaskId,
    caller_id: &DeviceId,
    now: DateTime<Utc>,
) -> Result<Change<Run>, ServerError> {
    let task = state
        .tasks
        .get(&task_id)
        .ok_or(ServerError::NotFound("the task"))?;
    require_task_access(state, caller_id, task)?;
    let run = start_run(state, task_id, caller_id, now)?;
    let event_text = format!("Started {}", describe_run(state, &run));
    let detail = describe_run_detail(state, &run);
    let topic = ChangeTopic::Run { run_id: run.id };
    Ok(Change::recorded(run, topic, event_text).with_detail(detail))
}

fn cancel_stored_run(
    state: &mut StoredState,
    run_id: RunId,
    now: DateTime<Utc>,
) -> Result<Change<Run>, ServerError> {
    let cancelled = cancel_run_record(find_run(state, run_id)?, now)?;
    Ok(store_changed_run(state, cancelled, "Cancelled"))
}

fn retry_stored_run(
    state: &mut StoredState,
    run_id: RunId,
) -> Result<Change<Run>, ServerError> {
    let retried = retry_run_record(find_run(state, run_id)?)?;
    Ok(store_changed_run(state, retried, "Retried"))
}

fn store_changed_run(
    state: &mut StoredState,
    changed: RunRecord,
    verb: &str,
) -> Change<Run> {
    let run = changed.run.clone();
    let run_id = run.id;
    state.runs.insert(run_id, changed);
    sync_task_status(state, run.task_id, run.status);
    let event_text = format!("{verb} {}", describe_run(state, &run));
    let detail = describe_run_detail(state, &run);
    Change::recorded(run, ChangeTopic::Run { run_id }, event_text)
        .with_detail(detail)
}

fn append_chat_message(
    state: &mut StoredState,
    run_id: RunId,
    request: &SendChatMessageRequest,
) -> Result<Change<Run>, ServerError> {
    let record = state
        .runs
        .get_mut(&run_id)
        .ok_or(ServerError::NotFound(UNKNOWN_RUN))?;
    record.run.chat.push(request.message.clone());
    let run = record.run.clone();
    let event_text =
        format!("Sent a message to {}", describe_run(state, &run));
    Ok(Change::recorded(
        run,
        ChangeTopic::Run { run_id },
        event_text,
    ))
}

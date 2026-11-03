use axum::Json;
use axum::extract::State;
use chrono::{DateTime, Utc};
use orchestration_api::updates::ChangeTopic;
use orchestration_api::work::{RunEvent, RunEventsRequest};
use orchestration_core::identifiers::{DeviceId, RunId};
use orchestration_core::run::{Run, RunFailure, StepStatus};
use orchestration_core::run_lifecycle::apply_step_status;
use orchestration_core::run_links::record_link_change;
use orchestration_core::step_results::record_step_result;
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::follow_ups::append_chat_message;
use crate::run_changes::is_step_finished;
use crate::run_starts::{describe_run, describe_run_detail, sync_task_status};
use crate::runs::{find_run, holds_step};
use crate::server::SharedServer;
use crate::stored_state::{RunRecord, StoredState};

const EVENT_TEXT_SEPARATOR: &str = "; ";

pub async fn post_run_events(
    State(server): State<SharedServer>,
    PathValue(run_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Run>, ServerError> {
    request.caller.require_runner()?;
    let events_request: RunEventsRequest = parse_json_body(&request.body)?;
    let run_id = RunId(run_uuid);
    let runner_id = &request.caller.device_id;
    let run = server.apply(runner_id, |state, now| {
        record_run_events(state, run_id, runner_id, &events_request, now)
    })?;
    Ok(Json(run))
}

fn record_run_events(
    state: &mut StoredState,
    run_id: RunId,
    runner_id: &DeviceId,
    request: &RunEventsRequest,
    now: DateTime<Utc>,
) -> Result<Change<Run>, ServerError> {
    let record = find_run(state, run_id)?;
    if !is_run_runner(record, runner_id) {
        return Err(ServerError::Forbidden(
            "the runner holds no step of this run",
        ));
    }
    let mut changed = record.clone();
    for event in &request.events {
        changed = apply_run_event(changed, event, runner_id, now)?;
    }
    let run = changed.run.clone();
    state.runs.insert(run_id, changed);

    sync_task_status(state, run.task_id, run.status);
    let run_label = describe_run(state, &run);
    let event_text = describe_events(&request.events, &run_label);
    let detail = describe_run_detail(state, &run);
    let change =
        Change::recorded(run, ChangeTopic::Run { run_id }, event_text);
    Ok(change.with_detail(detail))
}

fn is_run_runner(record: &RunRecord, runner_id: &DeviceId) -> bool {
    let is_pinned = record
        .pinned_steps
        .values()
        .any(|pinned_runner| pinned_runner == runner_id);
    is_pinned || holds_step(&record.run, runner_id)
}

fn apply_run_event(
    record: RunRecord,
    event: &RunEvent,
    runner_id: &DeviceId,
    now: DateTime<Utc>,
) -> Result<RunRecord, ServerError> {
    let mut run = record.run.clone();
    let changed_run = match event {
        RunEvent::ChatAppended { message } => {
            return Ok(append_chat_message(&record, message));
        }
        RunEvent::StepStatusChanged { step_name, status } => {
            require_held_step(&run, step_name, runner_id)?;
            apply_step_status(&run, step_name, *status, now)?
        }
        RunEvent::LogAppended { line } => {
            run.log.push(line.clone());
            run
        }
        RunEvent::SessionStarted { session } => {
            run.agent_session = Some(session.clone());
            run
        }
        RunEvent::WorktreeCreated { branch } => {
            run.worktree_branch = Some(branch.clone());
            run
        }
        RunEvent::LinkChanged { link } => record_link_change(&run, *link, now),
        RunEvent::Failed { failure } => {
            fail_step(&run, failure, runner_id, now)?
        }
        RunEvent::StepResultRecorded { step_name, result } => {
            require_held_step(&run, step_name, runner_id)?;
            record_step_result(&run, step_name, result)?
        }
        RunEvent::Finished => finish_held_steps(run, runner_id, now)?,
    };
    Ok(RunRecord {
        run: changed_run,
        ..record
    })
}

fn require_held_step(
    run: &Run,
    step_name: &str,
    runner_id: &DeviceId,
) -> Result<(), ServerError> {
    let step = run.steps.iter().find(|step| step.name == step_name);
    let is_held_by_other =
        step.is_some_and(|step| step.runner.as_ref() != Some(runner_id));
    if is_held_by_other {
        return Err(ServerError::Forbidden(
            "the step belongs to another runner",
        ));
    }
    Ok(())
}

fn fail_step(
    run: &Run,
    failure: &RunFailure,
    runner_id: &DeviceId,
    now: DateTime<Utc>,
) -> Result<Run, ServerError> {
    require_held_step(run, &failure.step_name, runner_id)?;
    let is_already_failed = run.steps.iter().any(|step| {
        step.name == failure.step_name && step.status == StepStatus::Failed
    });
    let failed_run = if is_already_failed {
        run.clone()
    } else {
        apply_step_status(run, &failure.step_name, StepStatus::Failed, now)?
    };
    let reported_failure = RunFailure {
        runner: Some(runner_id.clone()),
        ..failure.clone()
    };
    Ok(Run {
        failure: Some(reported_failure),
        ..failed_run
    })
}

fn finish_held_steps(
    run: Run,
    runner_id: &DeviceId,
    now: DateTime<Utc>,
) -> Result<Run, ServerError> {
    let unfinished_step_names: Vec<String> = run
        .steps
        .iter()
        .filter(|step| step.runner.as_ref() == Some(runner_id))
        .filter(|step| !is_step_finished(step.status))
        .map(|step| step.name.clone())
        .collect();
    let mut finished_run = run;
    for step_name in unfinished_step_names {
        finished_run = apply_step_status(
            &finished_run,
            &step_name,
            StepStatus::Done,
            now,
        )?;
    }
    Ok(finished_run)
}

fn describe_events(events: &[RunEvent], run_label: &str) -> String {
    let texts: Vec<String> = events
        .iter()
        .filter_map(|event| describe_event(event, run_label))
        .collect();
    if texts.is_empty() {
        return format!("Updated {run_label}");
    }
    texts.join(EVENT_TEXT_SEPARATOR)
}

fn describe_event(event: &RunEvent, run_label: &str) -> Option<String> {
    match event {
        RunEvent::StepStatusChanged { step_name, status } => {
            let verb = describe_step_status(*status);
            Some(format!("{verb} step {step_name} in {run_label}"))
        }
        RunEvent::Failed { failure } => {
            Some(format!("Failed step {} in {run_label}", failure.step_name))
        }
        RunEvent::Finished => Some(format!("Finished {run_label}")),
        RunEvent::LogAppended { .. }
        | RunEvent::StepResultRecorded { .. }
        | RunEvent::ChatAppended { .. }
        | RunEvent::SessionStarted { .. }
        | RunEvent::WorktreeCreated { .. }
        | RunEvent::LinkChanged { .. } => None,
    }
}

fn describe_step_status(status: StepStatus) -> &'static str {
    match status {
        StepStatus::Waiting => "Queued",
        StepStatus::Running => "Started",
        StepStatus::WaitingForApproval => "Paused for approval",
        StepStatus::Done => "Finished",
        StepStatus::Failed => "Failed",
        StepStatus::Skipped => "Skipped",
    }
}

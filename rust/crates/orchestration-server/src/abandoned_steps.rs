use chrono::{DateTime, TimeDelta, Utc};
use orchestration_api::updates::ChangeTopic;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{DeviceId, RunId};
use orchestration_core::run::RunStep;
use orchestration_core::run_lifecycle::{derive_run_status, is_run_finished};

use crate::change::Change;
use crate::claims::target_for_step;
use crate::error::ServerError;
use crate::request_ledger::Presence;
use crate::run_changes::{is_step_finished, requeue_step};
use crate::run_starts::{describe_run, find_run_workflow, sync_task_status};
use crate::server::Server;
use crate::stored_state::{RunRecord, StoredState};

pub const ABANDONED_STEP_TIMEOUT: TimeDelta = TimeDelta::minutes(2);
const EVENT_TEXT_SEPARATOR: &str = "; ";

#[derive(Debug)]
struct RunnerWatch {
    presence: Presence,
    watching_since: DateTime<Utc>,
    now: DateTime<Utc>,
}

impl RunnerWatch {
    fn has_abandoned(
        &self,
        state: &StoredState,
        runner_id: &DeviceId,
    ) -> bool {
        let is_revoked = state
            .devices
            .get(runner_id)
            .is_none_or(|device| device.revoked);
        let last_seen = self
            .presence
            .get(runner_id)
            .copied()
            .unwrap_or(self.watching_since);
        let is_silent = self.now - last_seen > ABANDONED_STEP_TIMEOUT;
        is_revoked || is_silent
    }
}

pub fn requeue_abandoned_steps(server: &Server) -> Result<usize, ServerError> {
    let watch = RunnerWatch {
        presence: server.presence_snapshot()?,
        watching_since: server.started_at(),
        now: server.now(),
    };
    let abandoned_runs =
        server.read(|state| Ok(find_abandoned_runs(state, &watch)))?;

    let scheduler_id = server.device_id();
    let mut released_count = 0;
    for run_id in abandoned_runs {
        released_count += server.apply(&scheduler_id, |state, _now| {
            release_abandoned_steps(state, run_id, &watch)
        })?;
    }
    Ok(released_count)
}

fn find_abandoned_runs(
    state: &StoredState,
    watch: &RunnerWatch,
) -> Vec<RunId> {
    let mut abandoned_runs = Vec::new();
    for (run_id, record) in &state.runs {
        let abandoned_steps = find_abandoned_steps(state, record, watch);
        if !abandoned_steps.is_empty() {
            abandoned_runs.push(*run_id);
        }
    }
    abandoned_runs
}

fn find_abandoned_steps(
    state: &StoredState,
    record: &RunRecord,
    watch: &RunnerWatch,
) -> Vec<String> {
    let mut step_names = Vec::new();
    if is_run_finished(record.run.status) {
        return step_names;
    }
    for step in &record.run.steps {
        if is_abandoned_step(state, record, step, watch) {
            step_names.push(step.name.clone());
        }
    }
    step_names
}

fn is_abandoned_step(
    state: &StoredState,
    record: &RunRecord,
    step: &RunStep,
    watch: &RunnerWatch,
) -> bool {
    let Some(holder) = &step.runner else {
        return false;
    };
    if is_step_finished(step.status) {
        return false;
    }
    if is_pinned_to(state, record, step, holder) {
        return false;
    }
    watch.has_abandoned(state, holder)
}

fn is_pinned_to(
    state: &StoredState,
    record: &RunRecord,
    step: &RunStep,
    holder: &DeviceId,
) -> bool {
    let Some(task) = state.tasks.get(&record.run.task_id) else {
        return false;
    };
    let workflow = find_run_workflow(state, record);
    let target = target_for_step(record, step, task, workflow);
    let holder_target = RunnerTarget::SpecificRunner {
        device_id: holder.clone(),
    };
    target == holder_target
}

fn release_abandoned_steps(
    state: &mut StoredState,
    run_id: RunId,
    watch: &RunnerWatch,
) -> Result<Change<usize>, ServerError> {
    let mut record = state
        .runs
        .get(&run_id)
        .cloned()
        .ok_or(ServerError::NotFound("the run"))?;
    let step_names = find_abandoned_steps(state, &record, watch);
    if step_names.is_empty() {
        return Ok(Change::unchanged(0));
    }

    let mut released_steps = Vec::new();
    for step in &record.run.steps {
        if step_names.contains(&step.name) {
            released_steps.push(requeue_step(step));
        } else {
            released_steps.push(step.clone());
        }
    }
    record.run.status = derive_run_status(&released_steps);
    record.run.steps = released_steps;

    let run_label = describe_run(state, &record.run);
    sync_task_status(state, record.run.task_id, record.run.status);
    state.runs.insert(run_id, record);

    let mut event_texts = Vec::new();
    for step_name in &step_names {
        event_texts.push(format!(
            "Put step {step_name} of {run_label} back to the queue"
        ));
    }
    let event_text = event_texts.join(EVENT_TEXT_SEPARATOR);
    let topic = ChangeTopic::Run { run_id };
    Ok(Change::recorded(step_names.len(), topic, event_text))
}

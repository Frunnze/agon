use chrono::{DateTime, Utc};
use orchestration_core::run::{Run, RunStatus, RunStep, StepStatus};
use orchestration_core::run_lifecycle::{derive_run_status, is_run_finished};

use crate::error::ServerError;
use crate::stored_state::RunRecord;

pub fn cancel_run_record(
    record: &RunRecord,
    now: DateTime<Utc>,
) -> Result<RunRecord, ServerError> {
    if is_run_finished(record.run.status) {
        return Err(ServerError::Conflict(
            "the run has already finished".to_owned(),
        ));
    }
    let mut run = record.run.clone();
    run.steps = run.steps.iter().map(skip_unfinished_step).collect();
    run.status = RunStatus::Cancelled;
    run.finished_at = Some(now);
    Ok(RunRecord {
        run,
        ..record.clone()
    })
}

pub fn retry_run_record(record: &RunRecord) -> Result<RunRecord, ServerError> {
    let can_retry =
        matches!(record.run.status, RunStatus::Failed | RunStatus::Cancelled);
    if !can_retry {
        return Err(ServerError::Conflict(
            "only a failed or cancelled run can be retried".to_owned(),
        ));
    }

    let mut pinned_steps = record.pinned_steps.clone();
    if let Some(failure) = &record.run.failure
        && failure.retry_runs_on_same_runner
        && let Some(runner_id) = &failure.runner
    {
        pinned_steps.insert(failure.step_name.clone(), runner_id.clone());
    }

    let reset_steps =
        record.run.steps.iter().map(reset_unfinished_step).collect();
    Ok(RunRecord {
        run: reopen_run(&record.run, reset_steps),
        pinned_steps,
        ..record.clone()
    })
}

pub fn reopen_run(run: &Run, steps: Vec<RunStep>) -> Run {
    Run {
        status: derive_run_status(&steps),
        steps,
        failure: None,
        finished_at: None,
        ..run.clone()
    }
}

pub fn is_step_finished(status: StepStatus) -> bool {
    matches!(
        status,
        StepStatus::Done | StepStatus::Failed | StepStatus::Skipped
    )
}

fn skip_unfinished_step(step: &RunStep) -> RunStep {
    if is_step_finished(step.status) {
        return step.clone();
    }
    RunStep {
        status: StepStatus::Skipped,
        ..step.clone()
    }
}

fn reset_unfinished_step(step: &RunStep) -> RunStep {
    let needs_reset =
        matches!(step.status, StepStatus::Failed | StepStatus::Skipped);
    if !needs_reset {
        return step.clone();
    }
    requeue_step(step)
}

pub fn requeue_step(step: &RunStep) -> RunStep {
    RunStep {
        runner: None,
        status: StepStatus::Waiting,
        started_at: None,
        finished_at: None,
        ..step.clone()
    }
}

use chrono::{DateTime, Utc};
use orchestration_core::device::RunnerLink;
use orchestration_core::identifiers::{DeviceId, RunId, TaskId};
use orchestration_core::run::{Run, RunStatus, StepStatus};
use serde::Serialize;

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct CurrentStep {
    pub number: usize,
    pub name: String,
    pub runner: Option<DeviceId>,
    pub status: StepStatus,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct RunProgress {
    pub run_id: RunId,
    pub number: u32,
    pub status: RunStatus,
    pub link: RunnerLink,
    pub started_at: DateTime<Utc>,
    pub finished_at: Option<DateTime<Utc>>,
    pub step_count: usize,
    pub current_step: Option<CurrentStep>,
}

#[must_use]
pub fn describe_run_progress(run: &Run) -> RunProgress {
    let mut current_step = None;
    for (index, step) in run.steps.iter().enumerate() {
        let is_finished =
            matches!(step.status, StepStatus::Done | StepStatus::Skipped);
        if !is_finished {
            current_step = Some(CurrentStep {
                number: index + 1,
                name: step.name.clone(),
                runner: step.runner.clone(),
                status: step.status,
            });
            break;
        }
    }

    RunProgress {
        run_id: run.id,
        number: run.number,
        status: run.status,
        link: run.link,
        started_at: run.started_at,
        finished_at: run.finished_at,
        step_count: run.steps.len(),
        current_step,
    }
}

#[must_use]
pub fn find_latest_run(runs: &[Run], task_id: TaskId) -> Option<&Run> {
    runs.iter()
        .filter(|run| run.task_id == task_id)
        .max_by_key(|run| run.number)
}

use std::time::Duration;

use chrono::{DateTime, Utc};
use orchestration_api::updates::ChangeTopic;
use orchestration_core::identifiers::{DeviceId, RunId, TaskId};
use orchestration_core::schedule_rules::next_run_after;
use orchestration_core::server_group::ServerStanding;
use orchestration_core::task::Task;

use crate::abandoned_steps::requeue_abandoned_steps;
use crate::change::Change;
use crate::error::ServerError;
use crate::logging::{log_requeue_failure, log_scheduler_failure};
use crate::run_starts::start_run;
use crate::server::{Server, SharedServer};
use crate::stored_state::StoredState;

const SCHEDULER_INTERVAL: Duration = Duration::from_secs(15);

#[must_use]
pub fn find_due_jobs(state: &StoredState, now: DateTime<Utc>) -> Vec<TaskId> {
    state
        .tasks
        .values()
        .filter(|task| is_job_due(state, task, now))
        .map(|task| task.id)
        .collect()
}

pub fn start_due_jobs(server: &Server) -> Result<Vec<RunId>, ServerError> {
    let now = server.now();
    let due_jobs = server.read(|state| Ok(find_due_jobs(state, now)))?;
    let scheduler_id = server.device_id();
    let mut started_runs = Vec::new();
    for task_id in due_jobs {
        let started_run = server.apply(&scheduler_id, |state, now| {
            start_due_job(state, task_id, &scheduler_id, now)
        })?;
        started_runs.extend(started_run);
    }
    Ok(started_runs)
}

pub async fn run_scheduler(server: SharedServer) {
    let mut ticker = tokio::time::interval(SCHEDULER_INTERVAL);
    loop {
        ticker.tick().await;
        if server.standing() == ServerStanding::Backup {
            continue;
        }
        if let Err(problem) = start_due_jobs(&server) {
            log_scheduler_failure(&problem);
        }
        if let Err(problem) = requeue_abandoned_steps(&server) {
            log_requeue_failure(&problem);
        }
    }
}

fn is_job_due(state: &StoredState, task: &Task, now: DateTime<Utc>) -> bool {
    let Some(schedule) = &task.schedule else {
        return false;
    };
    let checked_since = state
        .job_marks
        .get(&task.id)
        .copied()
        .unwrap_or(task.created_at);
    next_run_after(schedule, checked_since)
        .is_ok_and(|next_run| next_run <= now)
}

fn start_due_job(
    state: &mut StoredState,
    task_id: TaskId,
    scheduler_id: &DeviceId,
    now: DateTime<Utc>,
) -> Result<Change<Option<RunId>>, ServerError> {
    let title = state
        .tasks
        .get(&task_id)
        .map(|task| task.title.clone())
        .ok_or(ServerError::NotFound("the job"))?;
    state.job_marks.insert(task_id, now);
    match start_run(state, task_id, scheduler_id, now) {
        Ok(run) => {
            let event_text = format!("Started job {title} #{}", run.number);
            let topic = ChangeTopic::Run { run_id: run.id };
            Ok(Change::recorded(Some(run.id), topic, event_text))
        }
        Err(problem) => {
            let event_text = format!("Could not start job {title}: {problem}");
            Ok(Change::recorded(None, ChangeTopic::Tasks, event_text))
        }
    }
}

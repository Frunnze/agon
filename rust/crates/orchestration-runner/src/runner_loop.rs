use std::sync::Arc;

use orchestration_hub::cached_clones::list_cached_repositories;
use orchestration_hub::run_activity::{RunActivity, SleepPrevention};
use orchestration_hub::slots::{SlotCounter, SlotError};
use thiserror::Error;
use tokio::task::{JoinError, JoinSet};

use crate::heartbeat::describe_heartbeat;
use crate::run_executor::{RunExecutor, RunOutcome};
use crate::run_reports::report_step_failure;
use crate::runner_configuration::{
    ConfigurationProblem, RunnerConfiguration, validate_configuration,
};
use crate::runner_log::{
    log_cache_listing_failure, log_claim_failure, log_heartbeat_failure,
    log_run_task_failure, log_sleep_prevention_unavailable,
};
use crate::runner_server::RunnerServer;
use crate::steady_interval::steady_interval;

type ActiveRuns = JoinSet<RunOutcome>;

#[derive(Debug, Error)]
pub enum RunnerError {
    #[error(transparent)]
    Configuration(#[from] ConfigurationProblem),
    #[error(transparent)]
    Slots(#[from] SlotError),
}

enum LoopWake {
    ShutdownRequested,
    HeartbeatDue,
    ClaimDue,
    RunEnded(Result<RunOutcome, JoinError>),
}

pub async fn run_runner_loop<S: RunnerServer, E: RunExecutor>(
    server: Arc<S>,
    executor: Arc<E>,
    configuration: &RunnerConfiguration,
    shutdown: impl Future<Output = ()>,
) -> Result<(), RunnerError> {
    validate_configuration(configuration)?;
    let intervals = &configuration.intervals;
    let mut heartbeat_timer = steady_interval(intervals.heartbeat);
    let mut claim_timer = steady_interval(intervals.claim);
    let mut activity = RunActivity::new(configuration.slot_capacity);
    let mut active_runs = ActiveRuns::new();
    let mut is_shutting_down = false;
    tokio::pin!(shutdown);

    loop {
        if is_shutting_down && active_runs.is_empty() {
            return Ok(());
        }

        let wake = tokio::select! {
            () = &mut shutdown, if !is_shutting_down => {
                LoopWake::ShutdownRequested
            }
            _ = heartbeat_timer.tick() => LoopWake::HeartbeatDue,
            _ = claim_timer.tick(), if !is_shutting_down => LoopWake::ClaimDue,
            Some(ended) = active_runs.join_next() => LoopWake::RunEnded(ended),
        };

        match wake {
            LoopWake::ShutdownRequested => is_shutting_down = true,
            LoopWake::HeartbeatDue => {
                let slots = activity.slots();
                send_heartbeat(server.as_ref(), configuration, slots).await;
            }
            LoopWake::ClaimDue => {
                let server = server.as_ref();
                let runs = &mut active_runs;
                claim_free_slots(server, &executor, &mut activity, runs)
                    .await?;
            }
            LoopWake::RunEnded(ended) => release_slot(&mut activity, &ended)?,
        }
    }
}

async fn send_heartbeat<S: RunnerServer>(
    server: &S,
    configuration: &RunnerConfiguration,
    slots: SlotCounter,
) {
    let cache_root = &configuration.worktree_roots.cache_root;
    let cached_repositories = match list_cached_repositories(cache_root) {
        Ok(addresses) => addresses,
        Err(problem) => {
            log_cache_listing_failure(&problem);
            Vec::new()
        }
    };
    let heartbeat =
        describe_heartbeat(configuration, slots, cached_repositories);
    if let Err(problem) = server.send_heartbeat(&heartbeat).await {
        log_heartbeat_failure(&problem);
    }
}

async fn claim_free_slots<S: RunnerServer, E: RunExecutor>(
    server: &S,
    executor: &Arc<E>,
    activity: &mut RunActivity,
    active_runs: &mut ActiveRuns,
) -> Result<(), RunnerError> {
    while has_free_slot(activity.slots()) {
        let response = match server.claim_next_run().await {
            Ok(response) => response,
            Err(problem) => {
                log_claim_failure(&problem);
                return Ok(());
            }
        };
        let Some(assignment) = response.assignment else {
            return Ok(());
        };

        if let Err(problem) = activity.start_run() {
            let reason = problem.to_string();
            let run_id = assignment.run.id;
            let step_name = &assignment.step_name;
            report_step_failure(server, run_id, step_name, &reason).await;
            return Err(problem.into());
        }
        if let SleepPrevention::Unavailable(problem) =
            activity.sleep_prevention()
        {
            log_sleep_prevention_unavailable(problem);
        }

        let executor = Arc::clone(executor);
        active_runs.spawn(async move { executor.execute(assignment).await });
    }
    Ok(())
}

fn has_free_slot(slots: SlotCounter) -> bool {
    slots.busy_slots() < slots.capacity()
}

fn release_slot(
    activity: &mut RunActivity,
    ended: &Result<RunOutcome, JoinError>,
) -> Result<(), RunnerError> {
    if let Err(problem) = ended {
        log_run_task_failure(problem);
    }
    activity.finish_run()?;
    Ok(())
}

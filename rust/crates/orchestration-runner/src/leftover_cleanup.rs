use std::collections::BTreeSet;

use orchestration_api::work::ForgottenWork;
use orchestration_core::identifiers::TaskId;
use orchestration_hub::held_work::{HeldWork, list_held_work};
use orchestration_hub::leftover_removal::{
    remove_forgotten_tasks, remove_unused_clones,
};
use orchestration_hub::slots::SlotCounter;
use orchestration_hub::worktree_roots::WorktreeRoots;
use orchestration_hub::worktrees::WorktreeError;
use thiserror::Error;
use tokio::task::{JoinError, spawn_blocking};

use crate::heartbeat::send_heartbeat;
use crate::runner_configuration::RunnerConfiguration;
use crate::runner_log::{
    log_heartbeat_failure, log_leftover_listing_failure,
    log_leftover_removal_failure,
};
use crate::runner_server::RunnerServer;

#[derive(Debug, Error)]
pub(crate) enum LeftoverError {
    #[error(transparent)]
    Worktree(#[from] WorktreeError),
    #[error("a background task stopped unexpectedly: {0}")]
    BackgroundTask(#[from] JoinError),
}

pub(crate) async fn send_heartbeat_removing_leftovers<S: RunnerServer>(
    server: &S,
    configuration: &RunnerConfiguration,
    slots: SlotCounter,
) {
    let roots = configuration.worktree_roots.clone();
    let held_work = match list_held_work_in_background(roots.clone()).await {
        Ok(held_work) => held_work,
        Err(problem) => {
            log_leftover_listing_failure(&problem);
            HeldWork::default()
        }
    };

    let held_tasks = held_work.list_task_ids().into_iter().collect();
    let forgotten_work =
        match send_heartbeat(server, configuration, slots, held_tasks).await {
            Ok(forgotten_work) => forgotten_work,
            Err(problem) => {
                log_heartbeat_failure(&problem);
                return;
            }
        };

    let removal =
        remove_leftovers_in_background(roots, held_work, forgotten_work);
    if let Err(problem) = removal.await {
        log_leftover_removal_failure(&problem);
    }
}

async fn list_held_work_in_background(
    roots: WorktreeRoots,
) -> Result<HeldWork, LeftoverError> {
    let listing = spawn_blocking(move || list_held_work(&roots));
    Ok(listing.await??)
}

async fn remove_leftovers_in_background(
    roots: WorktreeRoots,
    held_work: HeldWork,
    forgotten_work: ForgottenWork,
) -> Result<(), LeftoverError> {
    let removal = spawn_blocking(move || {
        let forgotten_tasks: BTreeSet<TaskId> =
            forgotten_work.forgotten_tasks.into_iter().collect();
        remove_forgotten_tasks(&held_work, &forgotten_tasks)?;
        remove_unused_clones(&roots, &forgotten_work.unused_repositories)
    });
    Ok(removal.await??)
}

use orchestration_api::work::{ForgottenWork, HeartbeatRequest};
use orchestration_core::agent_place::find_sandbox_place;
use orchestration_core::identifiers::TaskId;
use orchestration_hub::cached_clones::list_cached_repositories;
use orchestration_hub::slots::SlotCounter;

use crate::runner_configuration::RunnerConfiguration;
use crate::runner_log::log_cache_listing_failure;
use crate::runner_server::{RunnerServer, ServerError};

#[must_use]
pub fn describe_heartbeat(
    configuration: &RunnerConfiguration,
    slots: SlotCounter,
    cached_repositories: Vec<String>,
    held_tasks: Vec<TaskId>,
) -> HeartbeatRequest {
    let mut offers = Vec::new();
    let mut allowed_hosts = Vec::new();
    for sandbox in &configuration.sandboxes {
        offers.extend(find_sandbox_place(sandbox.kind));
        allowed_hosts.extend(sandbox.allowed_hosts.iter().cloned());
    }

    HeartbeatRequest {
        labels: configuration.labels.clone(),
        slots_total: slots.capacity(),
        slots_busy: slots.busy_slots(),
        link: configuration.link,
        offers,
        allowed_hosts,
        cached_repositories,
        held_tasks,
    }
}

pub(crate) async fn send_heartbeat<S: RunnerServer>(
    server: &S,
    configuration: &RunnerConfiguration,
    slots: SlotCounter,
    held_tasks: Vec<TaskId>,
) -> Result<ForgottenWork, ServerError> {
    let cache_root = &configuration.worktree_roots.cache_root;
    let cached_repositories = match list_cached_repositories(cache_root) {
        Ok(addresses) => addresses,
        Err(problem) => {
            log_cache_listing_failure(&problem);
            Vec::new()
        }
    };
    let heartbeat = describe_heartbeat(
        configuration,
        slots,
        cached_repositories,
        held_tasks,
    );
    server.send_heartbeat(&heartbeat).await
}

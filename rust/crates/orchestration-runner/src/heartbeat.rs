use orchestration_api::work::HeartbeatRequest;
use orchestration_hub::slots::SlotCounter;

use crate::runner_configuration::RunnerConfiguration;

#[must_use]
pub fn describe_heartbeat(
    configuration: &RunnerConfiguration,
    slots: SlotCounter,
    cached_repositories: Vec<String>,
) -> HeartbeatRequest {
    HeartbeatRequest {
        labels: configuration.labels.clone(),
        slots_total: slots.capacity(),
        slots_busy: slots.busy_slots(),
        link: configuration.link,
        sandbox: configuration.sandbox.kind,
        allowed_hosts: configuration.sandbox.allowed_hosts.clone(),
        cached_repositories,
    }
}

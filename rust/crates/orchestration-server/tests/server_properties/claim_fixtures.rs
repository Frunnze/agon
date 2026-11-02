use axum::http::StatusCode;
use orchestration_api::work::{ClaimResponse, TaskStart};
use orchestration_core::device::{DeviceRole, RunnerTarget};
use orchestration_core::identifiers::ProjectId;
use orchestration_security::identity::DeviceIdentity;

use crate::fixtures::{
    Account, heartbeat_with, identity_from_seed, one_agent_task, pair_device,
    save_task, send_heartbeat,
};
use crate::test_client::TestServer;

pub const FIRST_RUNNER_SEED: u8 = 20;
pub async fn claim(
    test: &TestServer,
    runner: &DeviceIdentity,
) -> ClaimResponse {
    let response = test.post_empty(runner, "/runners/claim").await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

pub async fn pair_runners(
    test: &TestServer,
    account: &Account,
    runner_count: u8,
    slots_total: u32,
) -> Vec<DeviceIdentity> {
    let mut runners = Vec::new();
    for position in 0..runner_count {
        let identity = identity_from_seed(FIRST_RUNNER_SEED + position);
        let name = format!("runner-{position}");
        pair_device(test, account, &identity, &name, DeviceRole::Runner).await;
        let heartbeat = heartbeat_with(&[], slots_total, 0);
        send_heartbeat(test, &identity, &heartbeat).await;
        runners.push(identity);
    }
    runners
}

pub async fn queue_runs(
    test: &TestServer,
    account: &Account,
    project_id: ProjectId,
    runs_on: &RunnerTarget,
    run_count: usize,
) {
    for _position in 0..run_count {
        let task = one_agent_task(project_id, runs_on.clone(), None);
        save_task(test, account, task, TaskStart::Now).await;
    }
}

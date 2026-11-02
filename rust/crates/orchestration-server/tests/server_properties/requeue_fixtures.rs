use axum::http::StatusCode;
use orchestration_api::accounts::{RevokeDeviceRequest, revocation_statement};
use orchestration_api::work::{ClaimResponse, TaskStart};
use orchestration_core::device::{DeviceRole, RunnerTarget};
use orchestration_core::identifiers::DeviceId;
use orchestration_security::identity::DeviceIdentity;
use orchestration_server::StoredState;

use crate::fixtures::{
    Account, create_account, create_project, heartbeat_with,
    identity_from_seed, one_agent_task, pair_device, save_task,
    send_heartbeat,
};
use crate::test_client::TestServer;

pub const FIRST_RUNNER_SEED: u8 = 110;
pub const RUNNER_COUNT: u8 = 2;
pub const SLOTS_PER_RUNNER: u32 = 4;
pub const FREE_TASK_COUNT: usize = 2;

#[derive(Debug)]
pub struct RequeueSetup {
    pub account: Account,
    pub runners: Vec<DeviceIdentity>,
    pub pinned_runner: DeviceId,
}

pub async fn prepare_requeue(test: &TestServer) -> RequeueSetup {
    let account = create_account(test).await;
    let project = create_project(test, &account).await;
    let mut runners = Vec::new();
    for position in 0..RUNNER_COUNT {
        let identity = identity_from_seed(FIRST_RUNNER_SEED + position);
        let name = format!("runner-{position}");
        let role = DeviceRole::Runner;
        pair_device(test, &account, &identity, &name, role).await;
        let heartbeat = heartbeat_with(&[], SLOTS_PER_RUNNER, 0);
        send_heartbeat(test, &identity, &heartbeat).await;
        runners.push(identity);
    }

    for _position in 0..FREE_TASK_COUNT {
        let task =
            one_agent_task(project.id, RunnerTarget::AnyFreeRunner, None);
        save_task(test, &account, task, TaskStart::Now).await;
    }
    let pinned_runner = runners[0].device_id();
    let pinned_target = RunnerTarget::SpecificRunner {
        device_id: pinned_runner.clone(),
    };
    let pinned_task = one_agent_task(project.id, pinned_target, None);
    save_task(test, &account, pinned_task, TaskStart::Now).await;
    RequeueSetup {
        account,
        runners,
        pinned_runner,
    }
}

pub async fn claim_as(
    test: &TestServer,
    runner: &DeviceIdentity,
) -> (StatusCode, Option<ClaimResponse>) {
    let response = test.post_empty(runner, "/runners/claim").await;
    let claim = (response.status == StatusCode::OK).then(|| response.json());
    (response.status, claim)
}

pub async fn revoke_runner(
    test: &TestServer,
    account: &Account,
    runner: &DeviceIdentity,
) -> StatusCode {
    let runner_id = runner.device_id();
    let request = RevokeDeviceRequest {
        approval_signature: account
            .owner
            .sign(&revocation_statement(&runner_id)),
    };
    let path = format!("/devices/{}/revoke", runner_id.0);
    test.post(&account.owner, &path, &request).await.status
}

pub fn is_pinned_to(
    state: &StoredState,
    task_id: orchestration_core::identifiers::TaskId,
    runner_id: &DeviceId,
) -> bool {
    let expected_target = RunnerTarget::SpecificRunner {
        device_id: runner_id.clone(),
    };
    state
        .tasks
        .get(&task_id)
        .is_some_and(|task| task.runs_on == expected_target)
}

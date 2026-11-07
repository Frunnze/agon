use axum::http::StatusCode;
use orchestration_api::routes::{RUNNER_HEARTBEAT, RUNNERS};
use orchestration_core::device::{DeviceRole, Runner, RunnerTarget};
use orchestration_security::identity::DeviceIdentity;

use crate::claim_fixtures::{FIRST_RUNNER_SEED, claim, queue_runs};
use crate::fixtures::{
    Account, create_account, create_project, heartbeat_with,
    identity_from_seed, pair_device, send_heartbeat,
};
use crate::test_client::{TestResponse, TestServer};

const RUNNER_NAME: &str = "slot-runner";

pub struct SlotDesk {
    pub account: Account,
    pub runner: DeviceIdentity,
}

pub async fn open_slot_desk(
    test: &TestServer,
    slots_total: u32,
    slots_busy: u32,
    run_count: usize,
) -> SlotDesk {
    let account = create_account(test).await;
    let project = create_project(test, &account).await;
    let runner = identity_from_seed(FIRST_RUNNER_SEED);
    let role = DeviceRole::Runner;
    pair_device(test, &account, &runner, RUNNER_NAME, role).await;
    report_busy_slots(test, &runner, slots_total, slots_busy).await;
    let target = RunnerTarget::AnyFreeRunner;
    queue_runs(test, &account, project.id, &target, run_count).await;
    SlotDesk { account, runner }
}

pub async fn report_busy_slots(
    test: &TestServer,
    runner: &DeviceIdentity,
    slots_total: u32,
    slots_busy: u32,
) -> Runner {
    let heartbeat = heartbeat_with(&[], slots_total, slots_busy);
    send_heartbeat(test, runner, &heartbeat).await
}

pub async fn offer_busy_slots(
    test: &TestServer,
    runner: &DeviceIdentity,
    slots_total: u32,
    slots_busy: u32,
) -> TestResponse {
    let heartbeat = heartbeat_with(&[], slots_total, slots_busy);
    test.post(runner, RUNNER_HEARTBEAT, &heartbeat).await
}

pub async fn read_slot_runner(test: &TestServer, desk: &SlotDesk) -> Runner {
    let response = test.get(&desk.account.owner, RUNNERS).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    let runners: Vec<Runner> = response.json();
    let runner_id = desk.runner.device_id();
    runners
        .into_iter()
        .find(|runner| runner.device_id == runner_id)
        .expect("the slot runner is listed")
}

pub async fn claim_counting_work(test: &TestServer, desk: &SlotDesk) -> u32 {
    let response = claim(test, &desk.runner).await;
    u32::from(response.assignment.is_some())
}

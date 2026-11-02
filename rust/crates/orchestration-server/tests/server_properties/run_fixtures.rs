use axum::http::StatusCode;
use orchestration_api::work::{
    ClaimResponse, RunEvent, RunEventsRequest, TaskStart,
};
use orchestration_core::device::{DeviceRole, RunnerTarget};
use orchestration_core::run::Run;
use orchestration_security::identity::DeviceIdentity;

use crate::fixtures::{
    Account, create_account, create_project, heartbeat_with,
    identity_from_seed, one_agent_task, pair_device, save_task,
    send_heartbeat,
};
use crate::test_client::TestServer;

const FIRST_RUNNER_SEED: u8 = 40;
const SECOND_RUNNER_SEED: u8 = 41;

#[derive(Debug)]
pub struct ClaimedRun {
    pub account: Account,
    pub holder: DeviceIdentity,
    pub other: DeviceIdentity,
    pub run: Run,
}

pub async fn claim_by(
    test: &TestServer,
    runner: &DeviceIdentity,
) -> Option<Run> {
    let response: ClaimResponse =
        test.post_empty(runner, "/runners/claim").await.json();
    response.assignment.map(|assignment| assignment.run)
}

pub async fn start_claimed_run(test: &TestServer) -> ClaimedRun {
    let account = create_account(test).await;
    let project = create_project(test, &account).await;
    let first = identity_from_seed(FIRST_RUNNER_SEED);
    let second = identity_from_seed(SECOND_RUNNER_SEED);
    for (identity, name) in
        [(&first, "office-server"), (&second, "mac-studio")]
    {
        pair_device(test, &account, identity, name, DeviceRole::Runner).await;
        send_heartbeat(test, identity, &heartbeat_with(&[], 2, 0)).await;
    }
    let task = one_agent_task(project.id, RunnerTarget::AnyFreeRunner, None);
    save_task(test, &account, task, TaskStart::Now).await;
    if let Some(run) = claim_by(test, &first).await {
        return ClaimedRun {
            account,
            holder: first,
            other: second,
            run,
        };
    }
    let run = claim_by(test, &second)
        .await
        .expect("one of the runners gets the run");
    ClaimedRun {
        account,
        holder: second,
        other: first,
        run,
    }
}

fn events_path(run: &Run) -> String {
    format!("/runs/{}/events", run.id.0)
}

pub fn run_path(run: &Run) -> String {
    format!("/runs/{}", run.id.0)
}

pub async fn post_events(
    test: &TestServer,
    runner: &DeviceIdentity,
    run: &Run,
    events: Vec<RunEvent>,
) -> (StatusCode, Option<Run>) {
    let request = RunEventsRequest { events };
    let response = test.post(runner, &events_path(run), &request).await;
    let updated_run =
        (response.status == StatusCode::OK).then(|| response.json());
    (response.status, updated_run)
}

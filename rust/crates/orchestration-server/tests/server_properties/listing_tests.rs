use axum::http::StatusCode;
use chrono::TimeDelta;
use orchestration_api::catalog::CreateWorkspaceRequest;
use orchestration_api::routes::{RUNNERS, WORKSPACES};
use orchestration_api::work::TaskStart;
use orchestration_core::device::{DeviceRole, Runner, RunnerTarget};
use orchestration_core::identifiers::{TaskId, WorkspaceId};
use orchestration_core::run::Run;
use orchestration_core::workspace::Workspace;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::fixtures::{
    Account, SEALED_KEY_BYTES, WORKSPACE_NAME, create_account, create_project,
    heartbeat_with, identity_from_seed, one_agent_task, pair_device,
    save_task, send_heartbeat,
};
use crate::test_client::{TestServer, block_on};

const LISTING_CASES: u32 = 8;
const MOST_EXTRA_RUNS: usize = 3;
const MOST_RUNNERS: u8 = 3;
const MOST_SLOTS: u32 = 8;
const MOST_WORKSPACES: usize = 4;
const FIRST_RUNNER_SEED: u8 = 60;
const RUNNER_PRESENCE_SECONDS: i64 = 60;
const MOST_SILENT_SECONDS: i64 = 200;
const RUN_START_SPACING: TimeDelta = TimeDelta::seconds(1);
const WORKSPACE_NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,20}";

fn task_runs_path(task_id: TaskId) -> String {
    format!("/tasks/{}/runs", task_id.0)
}

async fn start_task_with_runs(
    test: &TestServer,
    account: &Account,
    task_id: TaskId,
    extra_runs: usize,
) {
    for _extra_run in 0..extra_runs {
        test.clock.advance(RUN_START_SPACING);
        let response = test
            .post_empty(&account.owner, &task_runs_path(task_id))
            .await;
        assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    }
}

async fn save_started_task(test: &TestServer, account: &Account) -> TaskId {
    let project = create_project(test, account).await;
    let task = one_agent_task(project.id, RunnerTarget::AnyFreeRunner, None);
    let saved = save_task(test, account, task, TaskStart::Now).await;
    saved.task.id
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LISTING_CASES))]

    #[test]
    fn test_list_task_runs_property_lists_only_its_runs_by_start_time(
        first_extra_runs in 0..=MOST_EXTRA_RUNS,
        second_extra_runs in 0..=MOST_EXTRA_RUNS,
    ) {
        let test = TestServer::start();
        let (first_task_id, listed_runs) = block_on(async {
            let account = create_account(&test).await;
            let first_task_id = save_started_task(&test, &account).await;
            let second_task_id = save_started_task(&test, &account).await;
            start_task_with_runs(
                &test,
                &account,
                first_task_id,
                first_extra_runs,
            )
            .await;
            start_task_with_runs(
                &test,
                &account,
                second_task_id,
                second_extra_runs,
            )
            .await;
            let response = test
                .get(&account.owner, &task_runs_path(first_task_id))
                .await;
            let listed_runs: Vec<Run> = response.json();
            (first_task_id, listed_runs)
        });

        prop_assert_eq!(listed_runs.len(), first_extra_runs + 1);
        let run_numbers = 1..;
        for (expected_number, run) in run_numbers.zip(&listed_runs) {
            prop_assert_eq!(run.task_id, first_task_id);
            prop_assert_eq!(run.number, expected_number);
        }
    }

    #[test]
    fn test_list_runners_property_shows_every_heartbeat_as_sent(
        slot_counts in vec(1..=MOST_SLOTS, 1..=usize::from(MOST_RUNNERS)),
    ) {
        let test = TestServer::start();
        let (sent_runners, listed_runners) = block_on(async {
            let account = create_account(&test).await;
            let mut sent_runners = Vec::new();
            for (position, slots_total) in slot_counts.iter().enumerate() {
                let seed_offset = u8::try_from(position)
                    .expect("there are only a few runners");
                let runner_seed = FIRST_RUNNER_SEED + seed_offset;
                let runner = identity_from_seed(runner_seed);
                let name = format!("runner-{position}");
                let role = DeviceRole::Runner;
                pair_device(&test, &account, &runner, &name, role).await;
                let heartbeat = heartbeat_with(&["mac"], *slots_total, 0);
                sent_runners
                    .push(send_heartbeat(&test, &runner, &heartbeat).await);
            }
            let listed_runners: Vec<Runner> =
                test.get(&account.owner, RUNNERS).await.json();
            (sent_runners, listed_runners)
        });

        prop_assert_eq!(listed_runners.len(), sent_runners.len());
        for sent_runner in &sent_runners {
            let listed_runner = listed_runners
                .iter()
                .find(|runner| runner.device_id == sent_runner.device_id);
            prop_assert_eq!(listed_runner, Some(sent_runner));
        }
    }

    #[test]
    fn test_list_runners_property_online_only_while_heartbeats_are_recent(
        silent_seconds in 0..=MOST_SILENT_SECONDS,
    ) {
        let test = TestServer::start();
        let listed_runners = block_on(async {
            let account = create_account(&test).await;
            let runner = identity_from_seed(FIRST_RUNNER_SEED);
            pair_device(&test, &account, &runner, "runner", DeviceRole::Runner)
                .await;
            send_heartbeat(&test, &runner, &heartbeat_with(&["mac"], 2, 0))
                .await;
            test.clock.advance(TimeDelta::seconds(silent_seconds));
            let listed_runners: Vec<Runner> =
                test.get(&account.owner, RUNNERS).await.json();
            listed_runners
        });

        let expected_online = silent_seconds <= RUNNER_PRESENCE_SECONDS;
        prop_assert_eq!(listed_runners.len(), 1);
        prop_assert_eq!(listed_runners[0].online, expected_online);
    }

    #[test]
    fn test_list_workspaces_property_lists_every_created_workspace(
        names in vec(WORKSPACE_NAME_PATTERN, 0..=MOST_WORKSPACES),
    ) {
        let test = TestServer::start();
        let (account_workspace_id, created_ids, listed) = block_on(async {
            let account = create_account(&test).await;
            let mut created_ids = Vec::new();
            for name in &names {
                let request = CreateWorkspaceRequest {
                    workspace_id: WorkspaceId(Uuid::new_v4()),
                    name: name.clone(),
                    sealed_workspace_key: SEALED_KEY_BYTES.to_vec(),
                };
                let response =
                    test.post(&account.owner, WORKSPACES, &request).await;
                assert_eq!(response.status, StatusCode::CREATED);
                created_ids.push(request.workspace_id);
            }
            let listed: Vec<Workspace> =
                test.get(&account.owner, WORKSPACES).await.json();
            (account.workspace_id, created_ids, listed)
        });

        prop_assert_eq!(listed.len(), names.len() + 1);
        let account_workspace = listed
            .iter()
            .find(|workspace| workspace.id == account_workspace_id);
        prop_assert_eq!(
            account_workspace.map(|workspace| workspace.name.as_str()),
            Some(WORKSPACE_NAME)
        );
        for (created_id, name) in created_ids.iter().zip(&names) {
            let listed_workspace = listed
                .iter()
                .find(|workspace| workspace.id == *created_id);
            prop_assert_eq!(
                listed_workspace.map(|workspace| &workspace.name),
                Some(name)
            );
        }
    }
}

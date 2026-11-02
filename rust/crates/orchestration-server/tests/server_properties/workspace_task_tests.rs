use std::collections::BTreeSet;

use axum::http::StatusCode;
use orchestration_api::routes::TASKS;
use orchestration_api::work::{RunAssignment, SaveTaskRequest, TaskStart};
use orchestration_core::device::DeviceRole;
use orchestration_core::identifiers::{DeviceId, WorkspaceId};
use orchestration_core::scope::Scope;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::claim_fixtures::{claim, pair_runners};
use crate::deletion_fixtures::{
    assert_deleted, create_workspace, list_task_ids, save_rule_with_scope,
    workspace_path,
};
use crate::fixtures::{
    create_account, identity_from_seed, pair_device, save_task, workspace_task,
};
use crate::test_client::{TestServer, block_on};

const WORKSPACE_TASK_CASES: u32 = 12;
const MAXIMUM_RUNNERS: u8 = 4;
const MAXIMUM_CLAIMS: usize = 12;
const RUNNER_SLOTS: u32 = 4;
const OTHER_WORKSPACE_NAME: &str = "personal";
const CLIENT_SEED: u8 = 40;

fn member_path(workspace_id: WorkspaceId, device_id: &DeviceId) -> String {
    format!("/workspaces/{}/devices/{}", workspace_id.0, device_id.0)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(WORKSPACE_TASK_CASES))]

    #[test]
    fn test_claim_next_run_property_a_workspace_task_goes_only_to_members(
        removed_flags in vec(any::<bool>(), 1..usize::from(MAXIMUM_RUNNERS)),
        claim_order in vec(0_usize..4, 1..MAXIMUM_CLAIMS),
    ) {
        let runner_count = u8::try_from(removed_flags.len())
            .map_err(|error| TestCaseError::fail(error.to_string()))?;
        let test = TestServer::start();
        let (workspace_id, members, assignments) = block_on(async {
            let account = create_account(&test).await;
            let slots = RUNNER_SLOTS;
            let runners =
                pair_runners(&test, &account, runner_count, slots).await;
            let mut members = BTreeSet::new();
            for (runner, is_removed) in runners.iter().zip(&removed_flags) {
                let runner_id = runner.device_id();
                if *is_removed {
                    let path = member_path(account.workspace_id, &runner_id);
                    test.delete(&account.owner, &path).await;
                } else {
                    members.insert(runner_id);
                }
            }
            save_rule_with_scope(&test, &account, Scope::everywhere()).await;
            let task = workspace_task(account.workspace_id);
            save_task(&test, &account, task, TaskStart::Now).await;

            let mut claimers = Vec::new();
            for runner_position in claim_order {
                claimers.push(&runners[runner_position % runners.len()]);
            }
            claimers.extend(&runners);
            let mut assignments: Vec<RunAssignment> = Vec::new();
            for runner in claimers {
                assignments.extend(claim(&test, runner).await.assignment);
            }
            (account.workspace_id, members, assignments)
        });

        let has_member = !members.is_empty();
        prop_assert_eq!(assignments.len(), usize::from(has_member));
        for assignment in &assignments {
            let runner = assignment.run.steps[0].runner.clone();
            let no_runner = || TestCaseError::fail("no runner");
            let runner = runner.ok_or_else(no_runner)?;
            prop_assert!(members.contains(&runner));
            prop_assert_eq!(assignment.workspace_id, workspace_id);
            prop_assert!(assignment.project.is_none());
            prop_assert!(assignment.skills.is_empty());
            prop_assert!(assignment.rules.is_empty());
        }
    }
}

#[test]
fn saving_a_task_in_an_unknown_workspace_is_refused() {
    let test = TestServer::start();
    let status = block_on(async {
        let account = create_account(&test).await;
        let unknown_workspace = WorkspaceId(Uuid::new_v4());
        let request = SaveTaskRequest {
            task: workspace_task(unknown_workspace),
            start: TaskStart::Now,
        };
        test.post(&account.owner, TASKS, &request).await.status
    });

    assert_eq!(status, StatusCode::NOT_FOUND);
}

#[test]
fn saving_a_task_in_a_workspace_of_others_is_forbidden() {
    let test = TestServer::start();
    let status = block_on(async {
        let account = create_account(&test).await;
        let client = identity_from_seed(CLIENT_SEED);
        pair_device(&test, &account, &client, "phone", DeviceRole::Client)
            .await;
        let other_workspace =
            create_workspace(&test, &account, OTHER_WORKSPACE_NAME).await;
        let request = SaveTaskRequest {
            task: workspace_task(other_workspace),
            start: TaskStart::Now,
        };
        test.post(&client, TASKS, &request).await.status
    });

    assert_eq!(status, StatusCode::FORBIDDEN);
}

#[test]
fn deleting_a_workspace_removes_its_workspace_tasks() {
    let test = TestServer::start();
    let (kept_task_id, task_ids) = block_on(async {
        let account = create_account(&test).await;
        let kept = workspace_task(account.workspace_id);
        let kept_task_id = kept.id;
        save_task(&test, &account, kept, TaskStart::Later).await;
        let doomed_id =
            create_workspace(&test, &account, OTHER_WORKSPACE_NAME).await;
        let doomed = workspace_task(doomed_id);
        save_task(&test, &account, doomed, TaskStart::Later).await;

        let deleted = test
            .delete(&account.owner, &workspace_path(doomed_id))
            .await;
        assert_deleted(&deleted);
        (kept_task_id, list_task_ids(&test, &account).await)
    });

    assert_eq!(task_ids, vec![kept_task_id]);
}

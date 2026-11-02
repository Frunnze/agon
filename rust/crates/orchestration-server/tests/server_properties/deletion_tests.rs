use axum::http::StatusCode;
use orchestration_api::work::CreateApprovalRequest;
use orchestration_core::approval::{ApprovalAction, ApprovalRequest};
use orchestration_core::device::{DeviceRole, RunnerTarget};
use orchestration_core::identifiers::{ProjectId, TaskId, WorkflowId};
use orchestration_core::run::Run;
use orchestration_core::workspace::Project;
use proptest::prelude::*;
use uuid::Uuid;

use crate::deletion_fixtures::{
    assert_deleted, cancel_run, list_task_ids, nightly_schedule, project_path,
    read_last_audit_event, save_project_in, save_waiting_task, start_task,
    task_path,
};
use crate::fixtures::{
    create_account, create_project, identity_from_seed, one_agent_task,
    pair_device, save_task,
};
use crate::test_client::{TestServer, block_on};
use crate::workflow_fixtures::{
    create_workflow, release_workflow, workflow_agent, workflow_task,
};

const DELETION_CASES: u32 = 8;
const RUNNER_SEED: u8 = 61;

fn workflow_path(workflow_id: WorkflowId) -> String {
    format!("/workflows/{}", workflow_id.0)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DELETION_CASES))]

    #[test]
    fn test_delete_task_property_removes_it_with_its_finished_runs(
        is_job in any::<bool>(),
        finished_run_count in 0_usize..3,
    ) {
        let test = TestServer::start();
        let (listed, runs, event) = block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            let schedule = is_job.then(nightly_schedule);
            let task = one_agent_task(
                project.id,
                RunnerTarget::AnyFreeRunner,
                schedule,
            );
            for _ in 0..finished_run_count {
                let run = start_task(&test, &account, task.clone()).await;
                cancel_run(&test, &account, &run).await;
            }
            save_task(
                &test,
                &account,
                task.clone(),
                orchestration_api::work::TaskStart::Later,
            )
            .await;
            assert_deleted(
                &test.delete(&account.owner, &task_path(task.id)).await,
            );
            let runs_path = format!("{}/runs", task_path(task.id));
            let runs: Vec<Run> =
                test.get(&account.owner, &runs_path).await.json();
            let listed = list_task_ids(&test, &account).await;
            let event = read_last_audit_event(&test, &account).await;
            (listed, runs, event)
        });

        prop_assert!(listed.is_empty());
        prop_assert!(runs.is_empty());
        let kind = if is_job { "job" } else { "task" };
        prop_assert_eq!(event, format!("Deleted {kind} Ship release 2.4"));
    }

    #[test]
    fn test_delete_task_property_refuses_while_its_run_is_unfinished(
        is_job in any::<bool>(),
    ) {
        let test = TestServer::start();
        let (status, listed, task_id) = block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            let schedule = is_job.then(nightly_schedule);
            let task = one_agent_task(
                project.id,
                RunnerTarget::AnyFreeRunner,
                schedule,
            );
            start_task(&test, &account, task.clone()).await;
            let response =
                test.delete(&account.owner, &task_path(task.id)).await;
            let listed = list_task_ids(&test, &account).await;
            (response.status, listed, task.id)
        });

        prop_assert_eq!(status, StatusCode::CONFLICT);
        prop_assert_eq!(listed, vec![task_id]);
    }

    #[test]
    fn test_delete_project_property_removes_only_its_own_tasks(
        own_task_count in 0_usize..3,
        other_task_count in 0_usize..3,
    ) {
        let test = TestServer::start();
        let (projects, listed, kept) = block_on(async {
            let account = create_account(&test).await;
            let doomed = create_project(&test, &account).await;
            let other =
                save_project_in(&test, &account, account.workspace_id).await;
            for _ in 0..own_task_count {
                save_waiting_task(&test, &account, doomed.id).await;
            }
            let mut kept: Vec<TaskId> = Vec::new();
            for _ in 0..other_task_count {
                kept.push(save_waiting_task(&test, &account, other.id).await.id);
            }
            assert_deleted(
                &test.delete(&account.owner, &project_path(doomed.id)).await,
            );
            let projects: Vec<Project> =
                test.get(&account.owner, "/projects").await.json();
            let listed = list_task_ids(&test, &account).await;
            (projects, listed, kept)
        });

        let project_ids: Vec<ProjectId> =
            projects.iter().map(|project| project.id).collect();
        prop_assert_eq!(project_ids.len(), 1);
        let mut sorted_listed = listed;
        sorted_listed.sort();
        let mut sorted_kept = kept;
        sorted_kept.sort();
        prop_assert_eq!(sorted_listed, sorted_kept);
    }

    #[test]
    fn test_delete_workflow_property_refuses_while_a_task_uses_it(
        is_job in any::<bool>(),
    ) {
        let test = TestServer::start();
        let (refused, after_task_deleted) = block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            let workflow = create_workflow(
                &test,
                &account,
                release_workflow(
                    workflow_agent("plan", RunnerTarget::AnyFreeRunner),
                    workflow_agent("build", RunnerTarget::AnyFreeRunner),
                ),
            )
            .await;
            let mut task = workflow_task(project.id, workflow.id);
            task.schedule = is_job.then(nightly_schedule);
            save_task(
                &test,
                &account,
                task.clone(),
                orchestration_api::work::TaskStart::Later,
            )
            .await;
            let path = workflow_path(workflow.id);
            let refused = test.delete(&account.owner, &path).await.status;
            test.delete(&account.owner, &task_path(task.id)).await;
            let deleted = test.delete(&account.owner, &path).await.status;
            (refused, deleted)
        });

        prop_assert_eq!(refused, StatusCode::CONFLICT);
        prop_assert_eq!(after_task_deleted, StatusCode::NO_CONTENT);
    }

    #[test]
    fn test_delete_property_unknown_records_are_not_found(
        route in 0_usize..4,
    ) {
        let test = TestServer::start();
        let status = block_on(async {
            let account = create_account(&test).await;
            let unknown = Uuid::new_v4();
            let paths = [
                format!("/tasks/{unknown}"),
                format!("/projects/{unknown}"),
                format!("/workflows/{unknown}"),
                format!("/workspaces/{unknown}"),
            ];
            test.delete(&account.owner, &paths[route]).await.status
        });

        prop_assert_eq!(status, StatusCode::NOT_FOUND);
    }
}

#[test]
fn deleting_a_project_with_a_running_task_is_refused() {
    let test = TestServer::start();
    let (refused, after_cancel, event) = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let task =
            one_agent_task(project.id, RunnerTarget::AnyFreeRunner, None);
        let run: Run = start_task(&test, &account, task).await;
        let path = project_path(project.id);
        let refused = test.delete(&account.owner, &path).await;
        cancel_run(&test, &account, &run).await;
        let after_cancel = test.delete(&account.owner, &path).await.status;
        let event = read_last_audit_event(&test, &account).await;
        (refused, after_cancel, event)
    });

    assert_eq!(refused.status, StatusCode::CONFLICT);
    assert_eq!(
        refused.error_message(),
        "a task in project acme-app is running; cancel its run first"
    );
    assert_eq!(after_cancel, StatusCode::NO_CONTENT);
    assert_eq!(event, "Deleted project acme-app");
}

#[test]
fn deleting_a_workflow_drops_its_signing_requests() {
    let test = TestServer::start();
    let (approvals, event) = block_on(async {
        let account = create_account(&test).await;
        let workflow = create_workflow(
            &test,
            &account,
            release_workflow(
                workflow_agent("plan", RunnerTarget::AnyFreeRunner),
                workflow_agent("build", RunnerTarget::AnyFreeRunner),
            ),
        )
        .await;
        let request = CreateApprovalRequest {
            run_id: None,
            action: ApprovalAction::SignWorkflow {
                workflow_id: workflow.id,
            },
        };
        let runner = identity_from_seed(RUNNER_SEED);
        pair_device(&test, &account, &runner, "gpu-box", DeviceRole::Runner)
            .await;
        let created = test.post(&runner, "/approvals", &request).await;
        assert!(created.status.is_success(), "{created:?}");
        let path = workflow_path(workflow.id);
        assert_deleted(&test.delete(&account.owner, &path).await);
        let approvals: Vec<ApprovalRequest> =
            test.get(&account.owner, "/approvals").await.json();
        let event = read_last_audit_event(&test, &account).await;
        (approvals, event)
    });

    assert!(approvals.is_empty(), "{approvals:?}");
    assert_eq!(event, "Deleted workflow release");
}

#[test]
fn runner_devices_cannot_delete_tasks() {
    let test = TestServer::start();
    let status = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let task = save_waiting_task(&test, &account, project.id).await;
        let runner = identity_from_seed(RUNNER_SEED);
        pair_device(&test, &account, &runner, "gpu-box", DeviceRole::Runner)
            .await;
        test.delete(&runner, &task_path(task.id)).await.status
    });

    assert_eq!(status, StatusCode::FORBIDDEN);
}

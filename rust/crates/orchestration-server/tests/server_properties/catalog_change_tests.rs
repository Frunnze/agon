use axum::http::StatusCode;
use orchestration_api::accounts::PairingRequestView;
use orchestration_api::catalog::{RemoveRepositoryRequest, WorkflowListing};
use orchestration_api::updates::AuditView;
use orchestration_api::work::{RunEvent, TaskStart, UpdateTaskRequest};
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::TaskId;
use orchestration_core::run::StepStatus;
use orchestration_core::task::{Task, TaskStatus};
use orchestration_core::workspace::Project;
use proptest::prelude::*;
use uuid::Uuid;

use crate::fixtures::{
    create_account, create_project, one_agent_task, save_task,
};
use crate::pairing_fixtures::start_pairing;
use crate::run_fixtures::{post_events, start_claimed_run};
use crate::test_client::{TestServer, block_on};
use crate::workflow_fixtures::{
    create_signed_workflow, workflow_with_connections,
};

fn task_path(task_id: TaskId) -> String {
    format!("/tasks/{}", task_id.0)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(8))]

    #[test]
    fn test_update_task_property_replaces_fields_but_keeps_identity(
        title in "[A-Za-z][A-Za-z ]{0,30}",
        details in "sealed:[a-z]{1,20}",
    ) {
        let test = TestServer::start();
        let (status, original, stored) = block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            let task =
                one_agent_task(project.id, RunnerTarget::AnyFreeRunner, None);
            let saved = save_task(&test, &account, task, TaskStart::Now).await;
            let changed = Task {
                title: title.clone(),
                details: details.clone(),
                status: TaskStatus::Done,
                created_at: chrono::DateTime::UNIX_EPOCH,
                ..saved.task.clone()
            };
            let request = UpdateTaskRequest { task: changed };
            let path = task_path(saved.task.id);
            let updated = test.put(&account.owner, &path, &request).await;
            let listed = test.get(&account.owner, "/tasks").await;
            let tasks: Vec<Task> = listed.json();
            (updated.status, saved.task, tasks)
        });

        prop_assert_eq!(status, StatusCode::OK);
        prop_assert_eq!(stored.len(), 1);
        let stored = &stored[0];
        prop_assert_eq!(stored.id, original.id);
        prop_assert_eq!(stored.status, original.status);
        prop_assert_eq!(stored.created_at, original.created_at);
        prop_assert_eq!(&stored.title, &title);
        prop_assert_eq!(&stored.details, &details);
    }
}

#[test]
fn updating_an_unknown_task_or_another_id_is_refused() {
    let test = TestServer::start();
    let (unknown, mismatched) = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let task =
            one_agent_task(project.id, RunnerTarget::AnyFreeRunner, None);
        let unknown_path = task_path(task.id);
        let request = UpdateTaskRequest { task: task.clone() };
        let unknown = test.put(&account.owner, &unknown_path, &request).await;
        let saved = save_task(&test, &account, task, TaskStart::Later).await;
        let saved_path = task_path(saved.task.id);
        let other_task = Task {
            id: TaskId(Uuid::new_v4()),
            ..saved.task
        };
        let request = UpdateTaskRequest { task: other_task };
        let mismatched = test.put(&account.owner, &saved_path, &request).await;
        (unknown.status, mismatched.status)
    });

    assert_eq!(unknown, StatusCode::NOT_FOUND);
    assert_eq!(mismatched, StatusCode::UNPROCESSABLE_ENTITY);
}

#[test]
fn removing_a_repository_leaves_the_others() {
    let test = TestServer::start();
    let (removed, missing) = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let path = format!("/projects/{}/repositories", project.id.0);
        let request = RemoveRepositoryRequest {
            address: "github.com/acme/app".to_owned(),
        };
        let removed =
            test.delete_with_body(&account.owner, &path, &request).await;
        let missing =
            test.delete_with_body(&account.owner, &path, &request).await;
        (removed, missing.status)
    });

    assert_eq!(removed.status, StatusCode::OK);
    let project: Project = removed.json();
    assert_eq!(project.repositories.len(), 0);
    assert_eq!(missing, StatusCode::NOT_FOUND);
}

#[test]
fn workflow_listings_record_signing_and_changes() {
    let test = TestServer::start();
    let (listings, owner_id) = block_on(async {
        let account = create_account(&test).await;
        let generated = workflow_with_connections(1, &[]);
        create_signed_workflow(&test, &account, generated).await;
        let listings: Vec<WorkflowListing> =
            test.get(&account.owner, "/workflows").await.json();
        (listings, account.owner.device_id())
    });

    assert_eq!(listings.len(), 1);
    let listing = &listings[0];
    assert_eq!(listing.signed_at, Some(test.now()));
    assert_eq!(listing.changed_at, Some(test.now()));
    assert_eq!(listing.changed_by.as_ref(), Some(&owner_id));
}

#[test]
fn pairing_requests_say_when_they_started() {
    let test = TestServer::start();
    let view = block_on(async {
        let account = create_account(&test).await;
        let session = start_pairing(&test, &account).await;
        let path = format!("/pairing/sessions/{}", session.code);
        let view: PairingRequestView =
            test.get(&account.owner, &path).await.json();
        view
    });

    assert_eq!(view.started_at, test.now());
    assert!(view.expires_at > view.started_at);
}

#[test]
fn run_events_add_a_detail_line_to_the_audit_log() {
    let test = TestServer::start();
    let audit = block_on(async {
        let claimed = start_claimed_run(&test).await;
        let step_name = claimed.run.steps[0].name.clone();
        let running = vec![RunEvent::StepStatusChanged {
            step_name,
            status: StepStatus::Running,
        }];
        post_events(&test, &claimed.holder, &claimed.run, running).await;
        let audit: AuditView =
            test.get(&claimed.account.owner, "/audit").await.json();
        audit
    });

    let last_entry = audit.entries.last().expect("the log has entries");
    assert_eq!(
        last_entry.detail.as_deref(),
        Some("Ship release 2.4 #1 · acme/app")
    );
    assert!(audit.intact);
}

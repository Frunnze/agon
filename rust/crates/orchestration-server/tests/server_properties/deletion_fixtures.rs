use axum::http::StatusCode;
use orchestration_api::catalog::{
    CreateWorkspaceRequest, SaveProjectRequest, SaveRuleRequest,
};
use orchestration_api::work::TaskStart;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{
    ProjectId, RuleId, TaskId, WorkspaceId,
};
use orchestration_core::library::Rule;
use orchestration_core::run::Run;
use orchestration_core::scope::Scope;
use orchestration_core::task::{Schedule, Task, TimeOfDay};
use orchestration_core::workspace::Project;
use uuid::Uuid;

use crate::fixtures::{
    Account, SEALED_DETAILS, SEALED_KEY_BYTES, one_agent_task, sample_project,
    save_task,
};
use crate::test_client::{TestResponse, TestServer};

pub const NIGHTLY_HOUR: u32 = 2;

pub fn task_path(task_id: TaskId) -> String {
    format!("/tasks/{}", task_id.0)
}

pub fn project_path(project_id: ProjectId) -> String {
    format!("/projects/{}", project_id.0)
}

pub fn workspace_path(workspace_id: WorkspaceId) -> String {
    format!("/workspaces/{}", workspace_id.0)
}

pub fn nightly_schedule() -> Schedule {
    Schedule::Day {
        at: TimeOfDay {
            hour: NIGHTLY_HOUR,
            minute: 0,
        },
    }
}

pub async fn save_project_in(
    test: &TestServer,
    account: &Account,
    workspace_id: WorkspaceId,
) -> Project {
    let request = SaveProjectRequest {
        project: sample_project(workspace_id),
    };
    let response = test.post(&account.owner, "/projects", &request).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

pub async fn save_waiting_task(
    test: &TestServer,
    account: &Account,
    project_id: ProjectId,
) -> Task {
    let task = one_agent_task(project_id, RunnerTarget::AnyFreeRunner, None);
    save_task(test, account, task, TaskStart::Later).await.task
}

pub async fn start_task(
    test: &TestServer,
    account: &Account,
    task: Task,
) -> Run {
    let saved = save_task(test, account, task, TaskStart::Now).await;
    saved.run.expect("a started task has a run")
}

pub async fn cancel_run(test: &TestServer, account: &Account, run: &Run) {
    let cancel_path = format!("/runs/{}/cancel", run.id.0);
    let response = test.post_empty(&account.owner, &cancel_path).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
}

pub async fn create_workspace(
    test: &TestServer,
    account: &Account,
    name: &str,
) -> WorkspaceId {
    let workspace_id = WorkspaceId(Uuid::new_v4());
    let request = CreateWorkspaceRequest {
        workspace_id,
        name: name.to_owned(),
        sealed_workspace_key: SEALED_KEY_BYTES.to_vec(),
    };
    let response = test.post(&account.owner, "/workspaces", &request).await;
    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    workspace_id
}

pub async fn save_rule_with_scope(
    test: &TestServer,
    account: &Account,
    scope: Scope,
) -> Rule {
    let rule = Rule {
        id: RuleId(Uuid::new_v4()),
        title: "Never push to main".to_owned(),
        details: SEALED_DETAILS.to_owned(),
        scope,
        enabled: true,
        added_at: test.now(),
    };
    let request = SaveRuleRequest { rule: rule.clone() };
    let response = test.post(&account.owner, "/rules", &request).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    rule
}

pub async fn list_task_ids(
    test: &TestServer,
    account: &Account,
) -> Vec<TaskId> {
    let tasks: Vec<Task> = test.get(&account.owner, "/tasks").await.json();
    tasks.iter().map(|task| task.id).collect()
}

pub async fn read_last_audit_event(
    test: &TestServer,
    account: &Account,
) -> String {
    let audit: orchestration_api::updates::AuditView =
        test.get(&account.owner, "/audit").await.json();
    audit
        .entries
        .last()
        .map(|entry| entry.event.clone())
        .unwrap_or_default()
}

pub fn assert_deleted(response: &TestResponse) {
    assert_eq!(response.status, StatusCode::NO_CONTENT, "{response:?}");
}

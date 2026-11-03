use axum::http::StatusCode;
use orchestration_api::catalog::{
    CreateWorkspaceRequest, SaveRuleRequest, SaveSkillRequest,
    SaveWorkflowRequest,
};
use orchestration_api::work::{SaveTaskRequest, TaskStart};
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{RuleId, SkillId, WorkspaceId};
use orchestration_core::library::{
    Rule, Skill, SkillImprovement, SkillSource, SkillUsage,
};
use orchestration_core::scope::Scope;
use orchestration_core::workspace::Project;
use proptest::prelude::*;
use uuid::Uuid;

use crate::fixtures::{
    Account, SEALED_DETAILS, SEALED_KEY_BYTES, one_agent_task, sample_project,
};
use crate::test_client::TestServer;
use crate::workflow_fixtures::{release_workflow, workflow_agent};

pub const SETUP_CHANGE_COUNT: usize = 2;

#[derive(Clone, Copy, Debug)]
pub enum Operation {
    SaveProject,
    SaveSkill,
    SaveRule,
    StartPairing,
    CreateWorkspace,
    SaveTaskForLater,
    SaveTaskAndStart,
    CreateWorkflow,
    ListProjects,
}

impl Operation {
    pub fn changes_state(self) -> bool {
        !matches!(self, Self::ListProjects)
    }
}

pub fn operation_strategy() -> impl Strategy<Value = Operation> {
    prop_oneof![
        Just(Operation::SaveProject),
        Just(Operation::SaveSkill),
        Just(Operation::SaveRule),
        Just(Operation::StartPairing),
        Just(Operation::CreateWorkspace),
        Just(Operation::SaveTaskForLater),
        Just(Operation::SaveTaskAndStart),
        Just(Operation::CreateWorkflow),
        Just(Operation::ListProjects),
    ]
}

pub fn count_changes(operations: &[Operation]) -> usize {
    operations
        .iter()
        .filter(|operation| operation.changes_state())
        .count()
}

pub async fn perform_operation(
    test: &TestServer,
    account: &Account,
    project: &Project,
    operation: Operation,
) -> StatusCode {
    let owner = &account.owner;
    let response = match operation {
        Operation::SaveProject => {
            let project = sample_project(account.workspace_id);
            let request =
                orchestration_api::catalog::SaveProjectRequest { project };
            test.post(owner, "/projects", &request).await
        }
        Operation::SaveSkill => {
            let request = SaveSkillRequest {
                skill: sample_skill(),
            };
            test.post(owner, "/skills", &request).await
        }
        Operation::SaveRule => {
            let request = SaveRuleRequest {
                rule: sample_rule(test),
            };
            test.post(owner, "/rules", &request).await
        }
        Operation::StartPairing => {
            test.post_empty(owner, "/pairing/sessions").await
        }
        Operation::CreateWorkspace => {
            let request = CreateWorkspaceRequest {
                workspace_id: WorkspaceId(Uuid::new_v4()),
                name: "personal".to_owned(),
                sealed_workspace_key: SEALED_KEY_BYTES.to_vec(),
            };
            test.post(owner, "/workspaces", &request).await
        }
        Operation::SaveTaskForLater => {
            save_task_request(test, account, project, TaskStart::Later).await
        }
        Operation::SaveTaskAndStart => {
            save_task_request(test, account, project, TaskStart::Now).await
        }
        Operation::CreateWorkflow => {
            let workflow = release_workflow(
                workflow_agent("plan", RunnerTarget::AnyFreeRunner),
                workflow_agent("build", RunnerTarget::AnyFreeRunner),
            );
            let request = SaveWorkflowRequest { workflow };
            test.post(owner, "/workflows", &request).await
        }
        Operation::ListProjects => test.get(owner, "/projects").await,
    };
    response.status
}

async fn save_task_request(
    test: &TestServer,
    account: &Account,
    project: &Project,
    start: TaskStart,
) -> crate::test_client::TestResponse {
    let task = one_agent_task(project.id, RunnerTarget::AnyFreeRunner, None);
    let request = SaveTaskRequest { task, start };
    test.post(&account.owner, "/tasks", &request).await
}

fn sample_skill() -> Skill {
    Skill {
        id: SkillId(Uuid::new_v4()),
        name: "ios-release".to_owned(),
        summary: "Ship the iOS app".to_owned(),
        instructions: SEALED_DETAILS.to_owned(),
        scope: Scope::everywhere(),
        usage: SkillUsage::WhenChosen,
        source: SkillSource::Created,
        improvement: SkillImprovement::Never,
        history: Vec::new(),
    }
}

fn sample_rule(test: &TestServer) -> Rule {
    Rule {
        id: RuleId(Uuid::new_v4()),
        title: "Never push to main".to_owned(),
        details: SEALED_DETAILS.to_owned(),
        scope: Scope::everywhere(),
        enabled: true,
        added_at: test.now(),
    }
}

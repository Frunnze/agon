use axum::http::StatusCode;
use orchestration_api::catalog::{SaveWorkflowRequest, SignWorkflowRequest};
use orchestration_api::routes::WORKFLOWS;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{
    ProjectId, WorkflowAgentId, WorkflowId,
};
use orchestration_core::scope::WorkspaceScope;
use orchestration_core::task::{Task, TaskDoer};
use orchestration_core::workflow::{
    AgentConnection, AgentKind, CanvasPosition, StepKind, Workflow,
    WorkflowAgent,
};
use orchestration_core::workflow_document::render_workflow_document;
use orchestration_security::documents::sign_document;
use uuid::Uuid;

use crate::fixtures::{Account, SEALED_DETAILS, one_agent_task};
use crate::test_client::TestServer;

pub fn workflow_task(project_id: ProjectId, workflow_id: WorkflowId) -> Task {
    Task {
        doer: TaskDoer::Workflow { workflow_id },
        ..one_agent_task(project_id, RunnerTarget::AnyFreeRunner, None)
    }
}

pub fn workflow_agent(name: &str, runs_on: RunnerTarget) -> WorkflowAgent {
    WorkflowAgent {
        id: WorkflowAgentId(Uuid::new_v4()),
        name: name.to_owned(),
        kind: Some(AgentKind::ClaudeCode),
        task: SEALED_DETAILS.to_owned(),
        runs_on,
        skills: Vec::new(),
        uses_automatic_skills: true,
        approval_policy: Some(ApprovalPolicy::AskBeforeRiskyActions),
        position: CanvasPosition {
            horizontal: 0.0,
            vertical: 0.0,
        },
        step_kind: StepKind::Agent,
    }
}

pub fn release_workflow(
    first: WorkflowAgent,
    second: WorkflowAgent,
) -> Workflow {
    let connection = AgentConnection::plain(first.id, second.id);
    Workflow {
        id: WorkflowId(Uuid::new_v4()),
        name: "release".to_owned(),
        availability: WorkspaceScope::AllWorkspaces,
        agents: vec![first, second],
        connections: vec![connection],
        signature: None,
    }
}

pub async fn create_workflow(
    test: &TestServer,
    account: &Account,
    workflow: Workflow,
) -> Workflow {
    let request = SaveWorkflowRequest { workflow };
    let response = test.post(&account.owner, WORKFLOWS, &request).await;
    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    response.json()
}

pub async fn create_signed_workflow(
    test: &TestServer,
    account: &Account,
    workflow: Workflow,
) -> Workflow {
    let created = create_workflow(test, account, workflow).await;
    let document = render_workflow_document(&created);
    let signature = sign_document(&account.owner, &document);
    let sign_path = format!("/workflows/{}/signature", created.id.0);
    let sign_request = SignWorkflowRequest { signature };
    let signed = test.post(&account.owner, &sign_path, &sign_request).await;
    assert_eq!(signed.status, StatusCode::OK, "{signed:?}");
    created
}

pub fn workflow_with_connections(
    agent_count: usize,
    connections: &[(usize, usize)],
) -> Workflow {
    let mut agents = Vec::new();
    for position in 0..agent_count {
        let name = format!("step-{position}");
        agents.push(workflow_agent(&name, RunnerTarget::AnyFreeRunner));
    }
    let mut agent_connections = Vec::new();
    for (from, to) in connections {
        agent_connections
            .push(AgentConnection::plain(agents[*from].id, agents[*to].id));
    }
    Workflow {
        id: WorkflowId(Uuid::new_v4()),
        name: "generated".to_owned(),
        availability: WorkspaceScope::AllWorkspaces,
        agents,
        connections: agent_connections,
        signature: None,
    }
}

use orchestration_api::catalog::{SaveWorkflowRequest, SignWorkflowRequest};
use orchestration_core::identifiers::{
    WorkflowId, WorkspaceId, generate_uuid,
};
use orchestration_core::naming::validate_name;
use orchestration_core::scope::WorkspaceScope;
use orchestration_core::scope_rules::workspace_scope_includes;
use orchestration_core::workflow::{AgentConnection, Workflow, WorkflowAgent};
use orchestration_core::workflow_document::render_workflow_document;
use orchestration_core::workflow_graph::validate_workflow;
use orchestration_security::documents::sign_document;
use serde::Deserialize;
use serde_json::Value;

use super::workflow_view::{
    WorkflowView, build_workflow_view, read_stored_workflow,
};
use crate::command_reply::encode_reply;
use crate::content_sealing::{open_workflow, seal_workflow};
use crate::node::{DeviceSession, Node};
use crate::node_error::NodeError;
use crate::server_client::SignedServerClient;

pub(super) const WORKFLOW_COMMAND_NAMES: [&str; 5] = [
    "list_workflows",
    "create_workflow",
    "save_workflow",
    "sign_workflow",
    "discard_workflow_change",
];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum WorkflowCommand {
    ListWorkflows {
        workspace_id: WorkspaceId,
    },
    CreateWorkflow {
        workspace_id: WorkspaceId,
        name: String,
        availability: WorkspaceScope,
        agents: Vec<WorkflowAgent>,
        connections: Vec<AgentConnection>,
    },
    SaveWorkflow {
        workspace_id: WorkspaceId,
        workflow: Workflow,
    },
    SignWorkflow {
        workflow_id: WorkflowId,
    },
    DiscardWorkflowChange {
        workflow_id: WorkflowId,
    },
}

pub(super) async fn handle_workflow_command(
    node: &Node,
    command: WorkflowCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    match command {
        WorkflowCommand::ListWorkflows { workspace_id } => {
            let devices = client.list_devices().await?;
            let mut workflow_views = Vec::new();
            for listing in client.list_workflows().await? {
                if workspace_scope_includes(
                    &listing.workflow.availability,
                    workspace_id,
                ) {
                    let workflow_view = build_workflow_view(
                        &session.keyring,
                        &listing,
                        &devices,
                    )?;
                    workflow_views.push(workflow_view);
                }
            }
            encode_reply(&workflow_views)
        }
        WorkflowCommand::CreateWorkflow {
            workspace_id,
            name,
            availability,
            agents,
            connections,
        } => {
            let workflow = Workflow {
                id: WorkflowId(generate_uuid()),
                name,
                availability,
                agents,
                connections,
                signature: None,
            };
            let request =
                prepare_workflow_upload(&session, workspace_id, &workflow)?;
            client.create_workflow(&request).await?;
            encode_reply(&show_workflow(&session, &client, workflow.id).await?)
        }
        WorkflowCommand::SaveWorkflow {
            workspace_id,
            workflow,
        } => {
            let request =
                prepare_workflow_upload(&session, workspace_id, &workflow)?;
            client.update_workflow(workflow.id, &request).await?;
            encode_reply(&show_workflow(&session, &client, workflow.id).await?)
        }
        WorkflowCommand::SignWorkflow { workflow_id } => {
            sign_workflow(&session, &client, workflow_id).await?;
            encode_reply(&show_workflow(&session, &client, workflow_id).await?)
        }
        WorkflowCommand::DiscardWorkflowChange { workflow_id } => {
            client.discard_workflow_change(workflow_id).await?;
            encode_reply(&show_workflow(&session, &client, workflow_id).await?)
        }
    }
}

pub(super) async fn show_workflow(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    workflow_id: WorkflowId,
) -> Result<WorkflowView, NodeError> {
    let stored_workflow = read_stored_workflow(client, workflow_id).await?;
    let devices = client.list_devices().await?;
    build_workflow_view(&session.keyring, &stored_workflow, &devices)
}

pub(super) fn prepare_workflow_upload(
    session: &DeviceSession,
    workspace_id: WorkspaceId,
    workflow: &Workflow,
) -> Result<SaveWorkflowRequest, NodeError> {
    validate_name(&workflow.name)?;
    validate_workflow(workflow)?;
    let workspace_key = session.keyring.key_for(workspace_id)?;
    Ok(SaveWorkflowRequest {
        workflow: seal_workflow(workspace_key, workflow)?,
    })
}

async fn sign_workflow(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    workflow_id: WorkflowId,
) -> Result<(), NodeError> {
    let stored = read_stored_workflow(client, workflow_id).await?;
    let opened_workflow = open_workflow(&session.keyring, &stored.workflow)?;
    validate_workflow(&opened_workflow)?;

    let sealed_document = render_workflow_document(&stored.workflow);
    let request = SignWorkflowRequest {
        signature: sign_document(&session.identity, &sealed_document),
    };
    client.sign_workflow(workflow_id, &request).await
}

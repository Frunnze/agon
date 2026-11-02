use orchestration_core::identifiers::{
    ProjectId, TaskId, WorkflowId, WorkspaceId,
};
use serde::Deserialize;
use serde_json::Value;

use crate::node::Node;
use crate::node_error::NodeError;

pub(super) const DELETION_COMMAND_NAMES: [&str; 4] = [
    "delete_project",
    "delete_workflow",
    "delete_task",
    "delete_workspace",
];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", deny_unknown_fields)]
pub(super) enum DeletionCommand {
    #[serde(rename = "delete_project")]
    Project { project_id: ProjectId },
    #[serde(rename = "delete_workflow")]
    Workflow { workflow_id: WorkflowId },
    #[serde(rename = "delete_task")]
    Task { task_id: TaskId },
    #[serde(rename = "delete_workspace")]
    Workspace { workspace_id: WorkspaceId },
}

pub(super) async fn handle_deletion_command(
    node: &Node,
    command: DeletionCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    match command {
        DeletionCommand::Project { project_id } => {
            client.delete_project(project_id).await?;
        }
        DeletionCommand::Workflow { workflow_id } => {
            client.delete_workflow(workflow_id).await?;
        }
        DeletionCommand::Task { task_id } => {
            client.delete_task(task_id).await?;
        }
        DeletionCommand::Workspace { workspace_id } => {
            client.delete_workspace(workspace_id).await?;
        }
    }
    Ok(Value::Null)
}

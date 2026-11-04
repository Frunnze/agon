use orchestration_api::catalog::SetProtectedFilesRequest;
use orchestration_core::identifiers::WorkspaceId;
use orchestration_core::protected_files::{
    ProtectedFiles, validate_protected_files,
};
use serde::Deserialize;
use serde_json::Value;

use crate::command_reply::encode_reply;
use crate::node::Node;
use crate::node_error::NodeError;

pub(super) const PROTECTED_FILES_COMMAND_NAMES: [&str; 2] =
    ["set_protected_files", "reset_protected_files"];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum ProtectedFilesCommand {
    SetProtectedFiles {
        workspace_id: WorkspaceId,
        patterns: Vec<String>,
    },
    ResetProtectedFiles {
        workspace_id: WorkspaceId,
    },
}

pub(super) async fn handle_protected_files_command(
    node: &Node,
    command: ProtectedFilesCommand,
) -> Result<Value, NodeError> {
    let (workspace_id, protected_files) = match command {
        ProtectedFilesCommand::SetProtectedFiles {
            workspace_id,
            patterns,
        } => (workspace_id, ProtectedFiles { patterns }),
        ProtectedFilesCommand::ResetProtectedFiles { workspace_id } => {
            (workspace_id, ProtectedFiles::default())
        }
    };
    validate_protected_files(&protected_files)?;

    let session = node.open_session()?;
    let request = SetProtectedFilesRequest { protected_files };
    let workspace = session
        .client()
        .set_protected_files(workspace_id, &request)
        .await?;
    encode_reply(&workspace)
}

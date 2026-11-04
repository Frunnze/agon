use serde::Deserialize;
use serde_json::Value;

#[cfg(feature = "app-server")]
use crate::app_server_hosting::{start_server_backup, stop_server_backup};
use crate::command_reply::encode_reply;
use crate::node::Node;
use crate::node_error::NodeError;
use crate::views::describe_fresh_app_servers;

pub(super) const SERVER_BACKUP_COMMAND_NAMES: [&str; 2] =
    ["start_server_backup", "stop_server_backup"];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum ServerBackupCommand {
    StartServerBackup,
    StopServerBackup,
}

pub(super) async fn handle_server_backup_command(
    node: &Node,
    command: ServerBackupCommand,
) -> Result<Value, NodeError> {
    match command {
        ServerBackupCommand::StartServerBackup => {
            start_backup_here(node).await?;
        }
        ServerBackupCommand::StopServerBackup => {
            stop_backup_here(node).await?;
        }
    }
    let session = node.open_session()?;
    let fresh_view = node.refresh_server_group(&session).await?;
    let own_device = &session.account.device;
    let view = describe_fresh_app_servers(&fresh_view, Some(own_device));
    encode_reply(&view)
}

#[cfg(feature = "app-server")]
async fn start_backup_here(node: &Node) -> Result<(), NodeError> {
    start_server_backup(node).await
}

#[cfg(feature = "app-server")]
async fn stop_backup_here(node: &Node) -> Result<(), NodeError> {
    stop_server_backup(node).await
}

#[cfg(not(feature = "app-server"))]
#[allow(clippy::unused_async)]
async fn start_backup_here(_node: &Node) -> Result<(), NodeError> {
    Err(NodeError::HostingUnavailable)
}

#[cfg(not(feature = "app-server"))]
#[allow(clippy::unused_async)]
async fn stop_backup_here(_node: &Node) -> Result<(), NodeError> {
    Err(NodeError::HostingUnavailable)
}

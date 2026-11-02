use orchestration_core::identifiers::RunId;
use serde::Deserialize;
use serde_json::Value;

use crate::command_reply::encode_reply;
use crate::node::Node;
use crate::node_error::NodeError;
use crate::peer_side::connect_to_runner;

pub(super) const LIVE_COMMAND_NAMES: [&str; 2] =
    ["watch_run", "stop_watching_run"];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum LiveCommand {
    WatchRun { run_id: RunId },
    StopWatchingRun { run_id: RunId },
}

pub(super) async fn handle_live_command(
    node: &Node,
    command: LiveCommand,
) -> Result<Value, NodeError> {
    let peer_side = node.peer_side()?;
    match command {
        LiveCommand::WatchRun { run_id } => {
            if !peer_side.watches.is_linked(run_id) {
                let session = node.open_session()?;
                let client = session.client();
                let run = client.read_run(run_id).await?;
                let devices = client.list_devices().await?;
                match connect_to_runner(peer_side, &devices, &run).await {
                    Ok(link) => peer_side.watches.start(run_id, link),
                    Err(problem) => {
                        peer_side.watches.record_unreachable(run_id, &problem);
                    }
                }
            }
            encode_reply(&peer_side.watches.take_view(run_id))
        }
        LiveCommand::StopWatchingRun { run_id } => {
            peer_side.watches.stop(run_id);
            Ok(Value::Null)
        }
    }
}

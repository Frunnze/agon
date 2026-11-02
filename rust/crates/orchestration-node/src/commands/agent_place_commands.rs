use serde::Deserialize;
use serde_json::Value;

use crate::node::Node;
use crate::node_error::NodeError;
use crate::runner_settings::AgentPlace;

pub(super) const AGENT_PLACE_COMMAND_NAMES: [&str; 1] = ["choose_agent_place"];

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum AgentPlaceCommand {
    ChooseAgentPlace { place: AgentPlace },
}

pub(super) fn handle_agent_place_command(
    node: &Node,
    command: AgentPlaceCommand,
) -> Result<Value, NodeError> {
    match command {
        AgentPlaceCommand::ChooseAgentPlace { place } => {
            node.choose_agent_place(place)?;
            Ok(Value::Null)
        }
    }
}

use orchestration_core::agent_place::AgentPlace;
use serde::Deserialize;
use serde_json::Value;

use crate::node::Node;
use crate::node_error::NodeError;

pub(super) const AGENT_PLACE_COMMAND_NAMES: [&str; 1] =
    ["choose_agent_offers"];

#[derive(Clone, Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum AgentPlaceCommand {
    ChooseAgentOffers { offers: Vec<AgentPlace> },
}

pub(super) fn handle_agent_place_command(
    node: &Node,
    command: &AgentPlaceCommand,
) -> Result<Value, NodeError> {
    match command {
        AgentPlaceCommand::ChooseAgentOffers { offers } => {
            node.choose_agent_offers(offers)?;
            Ok(Value::Null)
        }
    }
}

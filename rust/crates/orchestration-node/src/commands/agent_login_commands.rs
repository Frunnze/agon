use serde::Deserialize;
use serde_json::Value;

#[cfg(feature = "runner")]
use super::agent_login_status::read_agent_login_status;
#[cfg(feature = "runner")]
use crate::agent_credentials::{AgentCredential, AgentCredentialKind};
#[cfg(feature = "runner")]
use crate::command_reply::encode_reply;
use crate::node::Node;
use crate::node_error::NodeError;
use crate::runner_settings::AgentPlace;

pub(super) const AGENT_LOGIN_COMMAND_NAMES: [&str; 7] = [
    "agent_login_status",
    "start_agent_login",
    "read_agent_login",
    "type_agent_login",
    "stop_agent_login",
    "save_agent_api_key",
    "forget_agent_credential",
];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
#[cfg_attr(not(feature = "runner"), allow(dead_code))]
pub(super) enum AgentLoginCommand {
    AgentLoginStatus,
    StartAgentLogin { place: AgentPlace },
    ReadAgentLogin,
    TypeAgentLogin { keys: String },
    StopAgentLogin,
    SaveAgentApiKey { api_key: String },
    ForgetAgentCredential,
}

#[cfg(feature = "runner")]
pub(super) async fn handle_agent_login_command(
    node: &Node,
    command: AgentLoginCommand,
) -> Result<Value, NodeError> {
    if node.runner_state().settings_in_effect().is_none() {
        return Err(NodeError::RunnerUnavailable);
    }
    let desk = node.agent_login_desk();
    match command {
        AgentLoginCommand::AgentLoginStatus => {
            encode_reply(&read_agent_login_status(node).await?)
        }
        AgentLoginCommand::StartAgentLogin { place } => {
            desk.open(place, node.shared_agent_credentials())?;
            Ok(Value::Null)
        }
        AgentLoginCommand::ReadAgentLogin => encode_reply(&desk.read()),
        AgentLoginCommand::TypeAgentLogin { keys } => {
            desk.type_keys(&keys)?;
            Ok(Value::Null)
        }
        AgentLoginCommand::StopAgentLogin => {
            desk.close()?;
            Ok(Value::Null)
        }
        AgentLoginCommand::SaveAgentApiKey { api_key } => {
            let kind = AgentCredentialKind::ApiKey;
            let credential = AgentCredential::new(kind, &api_key)?;
            node.agent_credentials().keep(credential)?;
            Ok(Value::Null)
        }
        AgentLoginCommand::ForgetAgentCredential => {
            node.agent_credentials().forget()?;
            Ok(Value::Null)
        }
    }
}

#[cfg(not(feature = "runner"))]
#[allow(clippy::unused_async)]
pub(super) async fn handle_agent_login_command(
    _node: &Node,
    _command: AgentLoginCommand,
) -> Result<Value, NodeError> {
    Err(NodeError::RunnerUnavailable)
}

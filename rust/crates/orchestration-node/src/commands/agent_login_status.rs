use std::time::Duration;

use serde::Serialize;
use tokio::task::spawn_blocking;
use tokio::time::timeout;

use crate::agent_credentials::AgentCredentialKind;
use crate::agent_login::{ClaudeLogin, read_claude_login};
use crate::node::Node;

const STATUS_LIMIT: Duration = Duration::from_secs(20);

#[derive(Debug, Serialize)]
pub(super) struct AgentLoginStatusView {
    claude_login: ClaudeLogin,
    container_credential: Option<AgentCredentialKind>,
}

pub(super) async fn read_agent_login_status(
    node: &Node,
) -> AgentLoginStatusView {
    let asking = timeout(STATUS_LIMIT, spawn_blocking(read_claude_login));
    let claude_login = match asking.await {
        Ok(Ok(Ok(claude_login))) => claude_login,
        _ => ClaudeLogin::Unknown,
    };
    let kept_credential = node.agent_credentials().current();
    AgentLoginStatusView {
        claude_login,
        container_credential: kept_credential.map(|kept| kept.kind()),
    }
}

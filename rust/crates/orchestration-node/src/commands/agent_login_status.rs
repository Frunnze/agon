use std::time::Duration;

use serde::Serialize;
use tokio::task::spawn_blocking;
use tokio::time::timeout;

use crate::agent_credentials::AgentCredentialKind;
use crate::agent_login::{ClaudeLogin, read_claude_login};
use crate::node::Node;
use crate::node_error::NodeError;

const STATUS_LIMIT: Duration = Duration::from_secs(20);

#[derive(Debug, Serialize)]
pub(super) struct AgentLoginStatusView {
    claude_login: ClaudeLogin,
    container_credential: Option<AgentCredentialKind>,
}

pub(super) async fn read_agent_login_status(
    node: &Node,
) -> Result<AgentLoginStatusView, NodeError> {
    let asking = timeout(STATUS_LIMIT, spawn_blocking(read_claude_login));
    let answer = asking.await.map_err(|_| {
        NodeError::ClaudeStatusUnreadable(format!(
            "no answer within {} seconds",
            STATUS_LIMIT.as_secs()
        ))
    })?;
    let claude_login = answer.map_err(|problem| {
        NodeError::ClaudeStatusUnreadable(problem.to_string())
    })??;
    let kept_credential = node.agent_credentials().current();
    Ok(AgentLoginStatusView {
        claude_login,
        container_credential: kept_credential.map(|kept| kept.kind()),
    })
}

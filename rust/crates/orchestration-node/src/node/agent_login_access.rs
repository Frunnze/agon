#[cfg(feature = "runner")]
use std::sync::Arc;

use super::Node;
use crate::agent_credentials::AgentCredentials;
#[cfg(feature = "runner")]
use crate::agent_login::AgentLoginDesk;

impl Node {
    #[must_use]
    pub fn agent_credentials(&self) -> &AgentCredentials {
        &self.agent_credentials
    }

    #[cfg(feature = "runner")]
    pub(crate) fn shared_agent_credentials(&self) -> Arc<AgentCredentials> {
        Arc::clone(&self.agent_credentials)
    }

    #[cfg(feature = "runner")]
    pub(crate) fn agent_login_desk(&self) -> &AgentLoginDesk {
        &self.agent_login_desk
    }
}

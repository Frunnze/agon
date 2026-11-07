use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use orchestration_core::agent_place::AgentPlace;

use super::login_session::{AgentLoginView, LoginSession};
use crate::agent_credentials::AgentCredentials;
use crate::node_error::NodeError;

type OpenSession = Option<LoginSession>;

#[derive(Debug, Default)]
pub(crate) struct AgentLoginDesk {
    session: Mutex<OpenSession>,
}

impl AgentLoginDesk {
    pub(crate) fn open(
        &self,
        place: AgentPlace,
        credentials: Arc<AgentCredentials>,
    ) -> Result<(), NodeError> {
        let mut session = self.lock_session();
        let is_running = session
            .as_ref()
            .is_some_and(|open_session| !open_session.has_ended());
        if is_running {
            return Err(NodeError::AgentLoginOpen);
        }
        *session = Some(LoginSession::start(place, credentials)?);
        Ok(())
    }

    pub(crate) fn read(&self) -> Option<AgentLoginView> {
        self.lock_session().as_ref().map(LoginSession::view)
    }

    pub(crate) fn type_keys(&self, keys: &str) -> Result<(), NodeError> {
        let mut session = self.lock_session();
        let running_session = session
            .as_mut()
            .filter(|open_session| !open_session.has_ended())
            .ok_or(NodeError::NoAgentLogin)?;
        running_session.type_keys(keys)
    }

    pub(crate) fn close(&self) -> Result<(), NodeError> {
        let closed_session = self.lock_session().take();
        let Some(mut closed_session) = closed_session else {
            return Ok(());
        };
        closed_session.stop()
    }

    fn lock_session(&self) -> MutexGuard<'_, OpenSession> {
        self.session.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

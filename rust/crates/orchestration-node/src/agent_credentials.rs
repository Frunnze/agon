use std::borrow::Cow;
use std::fmt;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use serde::{Deserialize, Serialize};
use zeroize::Zeroizing;

use crate::identity_store::{IdentityStore, IdentityStoreError};
use crate::node_error::NodeError;

pub const LONG_LIVED_TOKEN_VARIABLE: &str = "CLAUDE_CODE_OAUTH_TOKEN";
pub const API_KEY_VARIABLE: &str = "ANTHROPIC_API_KEY";
const SECRET_FIELD: &str = "Claude Code token or API key";

type CurrentCredential = Option<AgentCredential>;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentCredentialKind {
    LongLivedToken,
    ApiKey,
}

#[derive(Clone, PartialEq, Eq)]
pub struct AgentCredential {
    kind: AgentCredentialKind,
    secret: Zeroizing<String>,
}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct StoredCredential<'stored> {
    kind: AgentCredentialKind,
    #[serde(borrow)]
    secret: Cow<'stored, str>,
}

#[derive(Debug)]
pub struct AgentCredentials {
    store: Arc<dyn IdentityStore>,
    current: Mutex<CurrentCredential>,
}

impl AgentCredential {
    pub fn new(
        kind: AgentCredentialKind,
        secret: &str,
    ) -> Result<Self, NodeError> {
        let trimmed = secret.trim();
        if trimmed.is_empty() {
            return Err(NodeError::EmptyText {
                field: SECRET_FIELD,
            });
        }
        let has_breaks = trimmed.chars().any(|character| {
            character.is_whitespace() || character.is_control()
        });
        if has_breaks {
            return Err(NodeError::InvalidAgentSecret);
        }
        Ok(Self {
            kind,
            secret: Zeroizing::new(trimmed.to_owned()),
        })
    }

    #[must_use]
    pub fn kind(&self) -> AgentCredentialKind {
        self.kind
    }

    #[must_use]
    pub fn secret(&self) -> &str {
        &self.secret
    }

    #[must_use]
    pub fn environment_variable(&self) -> &'static str {
        match self.kind {
            AgentCredentialKind::LongLivedToken => LONG_LIVED_TOKEN_VARIABLE,
            AgentCredentialKind::ApiKey => API_KEY_VARIABLE,
        }
    }

    fn encode(&self) -> Result<Zeroizing<Vec<u8>>, NodeError> {
        let stored = StoredCredential {
            kind: self.kind,
            secret: Cow::Borrowed(self.secret()),
        };
        Ok(Zeroizing::new(serde_json::to_vec(&stored)?))
    }

    fn decode(stored_bytes: &[u8]) -> Result<Self, NodeError> {
        let stored: StoredCredential<'_> =
            serde_json::from_slice(stored_bytes)
                .map_err(|_| IdentityStoreError::DamagedAgentCredential)?;
        Self::new(stored.kind, &stored.secret)
            .map_err(|_| IdentityStoreError::DamagedAgentCredential.into())
    }
}

impl fmt::Debug for AgentCredential {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("AgentCredential")
            .field("kind", &self.kind)
            .finish_non_exhaustive()
    }
}

impl AgentCredentials {
    pub fn open(store: Arc<dyn IdentityStore>) -> Result<Self, NodeError> {
        let stored_bytes = store.load_agent_credential()?;
        let current = match stored_bytes {
            Some(stored_bytes) => {
                Some(AgentCredential::decode(&stored_bytes)?)
            }
            None => None,
        };
        Ok(Self {
            store,
            current: Mutex::new(current),
        })
    }

    #[must_use]
    pub fn current(&self) -> CurrentCredential {
        self.lock_current().clone()
    }

    pub fn keep(&self, credential: AgentCredential) -> Result<(), NodeError> {
        let mut current = self.lock_current();
        let encoded = credential.encode()?;
        self.store.save_agent_credential(&encoded)?;
        *current = Some(credential);
        Ok(())
    }

    pub fn forget(&self) -> Result<(), NodeError> {
        let mut current = self.lock_current();
        self.store.forget_agent_credential()?;
        *current = None;
        Ok(())
    }

    fn lock_current(&self) -> MutexGuard<'_, CurrentCredential> {
        self.current.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

use std::collections::BTreeMap;

use orchestration_api::accounts::SealedWorkspaceKey;
use orchestration_core::identifiers::WorkspaceId;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::sealing::{
    WorkspaceKey, open_sealed, open_text, seal_for,
};

use crate::node_error::NodeError;

#[derive(Debug, Default)]
pub struct WorkspaceKeyring {
    keys: BTreeMap<WorkspaceId, WorkspaceKey>,
}

impl WorkspaceKeyring {
    #[must_use]
    pub fn from_keys(keys: BTreeMap<WorkspaceId, WorkspaceKey>) -> Self {
        Self { keys }
    }

    pub fn open_sealed_keys(
        identity: &DeviceIdentity,
        sealed_keys: &[SealedWorkspaceKey],
    ) -> Result<Self, NodeError> {
        let mut keys = BTreeMap::new();
        for sealed_key in sealed_keys {
            let key_bytes = open_sealed(identity, &sealed_key.sealed_key)?;
            let workspace_key = WorkspaceKey::from_bytes(&key_bytes)?;
            keys.insert(sealed_key.workspace_id, workspace_key);
        }
        Ok(Self { keys })
    }

    pub fn key_for(
        &self,
        workspace_id: WorkspaceId,
    ) -> Result<&WorkspaceKey, NodeError> {
        self.keys
            .get(&workspace_id)
            .ok_or(NodeError::MissingWorkspaceKey(workspace_id.0))
    }

    pub fn open_text(&self, sealed_text: &str) -> Result<String, NodeError> {
        for workspace_key in self.keys.values() {
            if let Ok(plain_text) = open_text(workspace_key, sealed_text) {
                return Ok(plain_text);
            }
        }
        Err(NodeError::UnreadableSealedText)
    }
}

pub fn seal_workspace_key(
    recipient_sealing_key: &[u8],
    workspace_key: &WorkspaceKey,
) -> Result<Vec<u8>, NodeError> {
    let key_bytes = workspace_key.to_bytes();
    Ok(seal_for(recipient_sealing_key, key_bytes.as_ref())?)
}

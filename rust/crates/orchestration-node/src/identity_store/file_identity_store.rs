use std::path::PathBuf;

use orchestration_security::identity::DeviceIdentity;
use orchestration_security::peer_addresses::PeerSecret;
use zeroize::Zeroizing;

use super::secret_files::{
    read_secret_file, remove_secret_file, write_secret_file,
};
use super::{
    IdentityStore, IdentityStoreError, PEER_SECRET_LENGTH,
    read_stored_identity, read_stored_peer_secret,
};

const PEER_SECRET_FILE_NAME: &str = "peer-secret.key";
const AGENT_CREDENTIAL_FILE_NAME: &str = "agent-credential.key";

#[derive(Debug)]
pub struct FileIdentityStore {
    identity_path: PathBuf,
    peer_secret_path: PathBuf,
    agent_credential_path: PathBuf,
}

impl FileIdentityStore {
    #[must_use]
    pub fn new(identity_path: PathBuf) -> Self {
        let peer_secret_path =
            identity_path.with_file_name(PEER_SECRET_FILE_NAME);
        let agent_credential_path =
            identity_path.with_file_name(AGENT_CREDENTIAL_FILE_NAME);
        Self {
            identity_path,
            peer_secret_path,
            agent_credential_path,
        }
    }
}

impl IdentityStore for FileIdentityStore {
    fn load_identity(
        &self,
    ) -> Result<Option<DeviceIdentity>, IdentityStoreError> {
        let Some(secret_bytes) = read_secret_file(&self.identity_path)? else {
            return Ok(None);
        };
        read_stored_identity(&secret_bytes).map(Some)
    }

    fn save_identity(
        &self,
        identity: &DeviceIdentity,
    ) -> Result<(), IdentityStoreError> {
        let secret = identity.secret_bytes();
        write_secret_file(&self.identity_path, secret.as_slice())
    }

    fn load_peer_secret(
        &self,
    ) -> Result<Option<PeerSecret>, IdentityStoreError> {
        let Some(secret_bytes) = read_secret_file(&self.peer_secret_path)?
        else {
            return Ok(None);
        };
        read_stored_peer_secret(&secret_bytes).map(Some)
    }

    fn save_peer_secret(
        &self,
        secret: &[u8; PEER_SECRET_LENGTH],
    ) -> Result<(), IdentityStoreError> {
        write_secret_file(&self.peer_secret_path, secret)
    }

    fn forget_identity(&self) -> Result<(), IdentityStoreError> {
        remove_secret_file(&self.identity_path)
    }

    fn forget_peer_secret(&self) -> Result<(), IdentityStoreError> {
        remove_secret_file(&self.peer_secret_path)
    }

    fn load_agent_credential(
        &self,
    ) -> Result<Option<Zeroizing<Vec<u8>>>, IdentityStoreError> {
        let stored = read_secret_file(&self.agent_credential_path)?;
        Ok(stored.map(Zeroizing::new))
    }

    fn save_agent_credential(
        &self,
        encoded: &[u8],
    ) -> Result<(), IdentityStoreError> {
        write_secret_file(&self.agent_credential_path, encoded)
    }

    fn forget_agent_credential(&self) -> Result<(), IdentityStoreError> {
        remove_secret_file(&self.agent_credential_path)
    }
}

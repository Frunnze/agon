use std::path::{Path, PathBuf};

use orchestration_security::identity::DeviceIdentity;
use orchestration_security::peer_addresses::PeerSecret;
use orchestration_security::sealing::WorkspaceKey;
use zeroize::Zeroizing;

use super::secret_files::{
    read_secret_file, remove_secret_file, write_secret_file,
};
use super::{
    IdentityStore, IdentityStoreError, PEER_SECRET_LENGTH,
    read_stored_identity, read_stored_peer_secret,
};

const PEER_SECRET_FILE_NAME: &str = "peer-secret.sealed";
const AGENT_CREDENTIAL_FILE_NAME: &str = "agent-credential.sealed";

#[derive(Debug)]
pub struct EncryptedFileIdentityStore {
    identity_path: PathBuf,
    peer_secret_path: PathBuf,
    agent_credential_path: PathBuf,
    file_key: WorkspaceKey,
}

impl EncryptedFileIdentityStore {
    pub fn new(
        identity_path: PathBuf,
        key_bytes: &[u8],
    ) -> Result<Self, IdentityStoreError> {
        let file_key = WorkspaceKey::from_bytes(key_bytes)
            .map_err(|_| IdentityStoreError::InvalidStoreKey)?;
        let peer_secret_path =
            identity_path.with_file_name(PEER_SECRET_FILE_NAME);
        let agent_credential_path =
            identity_path.with_file_name(AGENT_CREDENTIAL_FILE_NAME);
        Ok(Self {
            identity_path,
            peer_secret_path,
            agent_credential_path,
            file_key,
        })
    }

    fn read_sealed(
        &self,
        path: &Path,
    ) -> Result<Option<Zeroizing<Vec<u8>>>, IdentityStoreError> {
        let Some(sealed_bytes) = read_secret_file(path)? else {
            return Ok(None);
        };
        let secret_bytes = self
            .file_key
            .decrypt(&sealed_bytes)
            .map_err(|_| IdentityStoreError::WrongStoreKey)?;
        Ok(Some(Zeroizing::new(secret_bytes)))
    }

    fn write_sealed(
        &self,
        path: &Path,
        secret: &[u8],
    ) -> Result<(), IdentityStoreError> {
        let sealed_bytes = self
            .file_key
            .encrypt(secret)
            .map_err(|_| IdentityStoreError::SealingFailed)?;
        write_secret_file(path, &sealed_bytes)
    }
}

impl IdentityStore for EncryptedFileIdentityStore {
    fn load_identity(
        &self,
    ) -> Result<Option<DeviceIdentity>, IdentityStoreError> {
        let Some(secret_bytes) = self.read_sealed(&self.identity_path)? else {
            return Ok(None);
        };
        read_stored_identity(&secret_bytes).map(Some)
    }

    fn save_identity(
        &self,
        identity: &DeviceIdentity,
    ) -> Result<(), IdentityStoreError> {
        let secret = identity.secret_bytes();
        self.write_sealed(&self.identity_path, secret.as_slice())
    }

    fn load_peer_secret(
        &self,
    ) -> Result<Option<PeerSecret>, IdentityStoreError> {
        let Some(secret_bytes) = self.read_sealed(&self.peer_secret_path)?
        else {
            return Ok(None);
        };
        read_stored_peer_secret(&secret_bytes).map(Some)
    }

    fn save_peer_secret(
        &self,
        secret: &[u8; PEER_SECRET_LENGTH],
    ) -> Result<(), IdentityStoreError> {
        self.write_sealed(&self.peer_secret_path, secret)
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
        self.read_sealed(&self.agent_credential_path)
    }

    fn save_agent_credential(
        &self,
        encoded: &[u8],
    ) -> Result<(), IdentityStoreError> {
        self.write_sealed(&self.agent_credential_path, encoded)
    }

    fn forget_agent_credential(&self) -> Result<(), IdentityStoreError> {
        remove_secret_file(&self.agent_credential_path)
    }
}

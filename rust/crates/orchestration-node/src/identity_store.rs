mod encrypted_file_identity_store;
mod file_identity_store;
mod keychain_identity_store;
mod platform_keychain;
mod secret_files;

use orchestration_security::identity::DeviceIdentity;
use orchestration_security::peer_addresses::PeerSecret;
use thiserror::Error;
use zeroize::Zeroizing;

use crate::device_files::DeviceFiles;
use crate::node_configuration::IdentityStoreChoice;
use crate::node_error::NodeError;

pub use encrypted_file_identity_store::EncryptedFileIdentityStore;
pub use file_identity_store::FileIdentityStore;
pub use keychain_identity_store::KeychainIdentityStore;

pub const PEER_SECRET_LENGTH: usize = 32;
const KEYCHAIN_SERVICE_NAME: &str = "agents-orchestration";

#[derive(Debug, Error)]
pub enum IdentityStoreError {
    #[error("the operating system keychain failed: {0}")]
    Keychain(String),
    #[error("the identity file could not be used: {0}")]
    File(#[from] std::io::Error),
    #[error("the stored device identity is damaged")]
    DamagedIdentity,
    #[error("the stored peer secret is damaged")]
    DamagedPeerSecret,
    #[error("the stored Claude Code token or API key is damaged")]
    DamagedAgentCredential,
    #[error("the identity store key must be 32 bytes written as hex")]
    InvalidStoreKey,
    #[error("the identity store cannot be opened with this key")]
    WrongStoreKey,
    #[error("the identity could not be encrypted")]
    SealingFailed,
}

pub trait IdentityStore: Send + Sync + std::fmt::Debug {
    fn load_identity(
        &self,
    ) -> Result<Option<DeviceIdentity>, IdentityStoreError>;

    fn save_identity(
        &self,
        identity: &DeviceIdentity,
    ) -> Result<(), IdentityStoreError>;

    fn load_peer_secret(
        &self,
    ) -> Result<Option<PeerSecret>, IdentityStoreError>;

    fn save_peer_secret(
        &self,
        secret: &[u8; PEER_SECRET_LENGTH],
    ) -> Result<(), IdentityStoreError>;

    fn forget_identity(&self) -> Result<(), IdentityStoreError>;

    fn forget_peer_secret(&self) -> Result<(), IdentityStoreError>;

    fn load_agent_credential(
        &self,
    ) -> Result<Option<Zeroizing<Vec<u8>>>, IdentityStoreError>;

    fn save_agent_credential(
        &self,
        encoded: &[u8],
    ) -> Result<(), IdentityStoreError>;

    fn forget_agent_credential(&self) -> Result<(), IdentityStoreError>;
}

fn read_stored_identity(
    secret_bytes: &[u8],
) -> Result<DeviceIdentity, IdentityStoreError> {
    DeviceIdentity::from_secret_bytes(secret_bytes)
        .map_err(|_| IdentityStoreError::DamagedIdentity)
}

fn read_stored_peer_secret(
    secret_bytes: &[u8],
) -> Result<PeerSecret, IdentityStoreError> {
    let secret: [u8; PEER_SECRET_LENGTH] = secret_bytes
        .try_into()
        .map_err(|_| IdentityStoreError::DamagedPeerSecret)?;
    Ok(Zeroizing::new(secret))
}

pub(crate) fn open_identity_store(
    choice: &IdentityStoreChoice,
    device_files: &DeviceFiles,
) -> Result<Box<dyn IdentityStore>, NodeError> {
    match choice {
        IdentityStoreChoice::Keychain => {
            let store = KeychainIdentityStore::new(KEYCHAIN_SERVICE_NAME);
            store.ensure_available()?;
            Ok(Box::new(store))
        }
        IdentityStoreChoice::File => {
            let identity_path = device_files.identity_path();
            Ok(Box::new(FileIdentityStore::new(identity_path)))
        }
        IdentityStoreChoice::EncryptedFile { key } => {
            let key_bytes = Zeroizing::new(
                hex::decode(key)
                    .map_err(|_| IdentityStoreError::InvalidStoreKey)?,
            );
            let identity_path = device_files.sealed_identity_path();
            let store =
                EncryptedFileIdentityStore::new(identity_path, &key_bytes)?;
            Ok(Box::new(store))
        }
    }
}

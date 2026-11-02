use keyring_core::{Entry, Error as KeychainError};
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::peer_addresses::PeerSecret;
use zeroize::Zeroizing;

use super::platform_keychain::ensure_platform_store;
use super::{
    IdentityStore, IdentityStoreError, PEER_SECRET_LENGTH,
    read_stored_identity, read_stored_peer_secret,
};

const IDENTITY_ACCOUNT_NAME: &str = "device-identity";
const PEER_SECRET_ACCOUNT_NAME: &str = "peer-secret";
const AGENT_CREDENTIAL_ACCOUNT_NAME: &str = "agent-credential";

#[derive(Debug)]
pub struct KeychainIdentityStore {
    service_name: String,
}

impl KeychainIdentityStore {
    #[must_use]
    pub fn new(service_name: &str) -> Self {
        Self {
            service_name: service_name.to_owned(),
        }
    }

    pub fn ensure_available(&self) -> Result<(), IdentityStoreError> {
        ensure_platform_store()
    }

    fn open_entry(
        &self,
        account_name: &str,
    ) -> Result<Entry, IdentityStoreError> {
        ensure_platform_store()?;
        Entry::new(&self.service_name, account_name)
            .map_err(|error| describe_keychain_error(&error))
    }

    fn read_secret(
        &self,
        account_name: &str,
    ) -> Result<Option<Vec<u8>>, IdentityStoreError> {
        let entry = self.open_entry(account_name)?;
        match entry.get_secret() {
            Ok(secret_bytes) => Ok(Some(secret_bytes)),
            Err(KeychainError::NoEntry) => Ok(None),
            Err(error) => Err(describe_keychain_error(&error)),
        }
    }

    fn write_secret(
        &self,
        account_name: &str,
        secret: &[u8],
    ) -> Result<(), IdentityStoreError> {
        let entry = self.open_entry(account_name)?;
        entry
            .set_secret(secret)
            .map_err(|error| describe_keychain_error(&error))
    }

    fn delete_secret(
        &self,
        account_name: &str,
    ) -> Result<(), IdentityStoreError> {
        let entry = self.open_entry(account_name)?;
        match entry.delete_credential() {
            Ok(()) | Err(KeychainError::NoEntry) => Ok(()),
            Err(error) => Err(describe_keychain_error(&error)),
        }
    }
}

impl IdentityStore for KeychainIdentityStore {
    fn load_identity(
        &self,
    ) -> Result<Option<DeviceIdentity>, IdentityStoreError> {
        let Some(secret_bytes) = self.read_secret(IDENTITY_ACCOUNT_NAME)?
        else {
            return Ok(None);
        };
        read_stored_identity(&secret_bytes).map(Some)
    }

    fn save_identity(
        &self,
        identity: &DeviceIdentity,
    ) -> Result<(), IdentityStoreError> {
        let secret = identity.secret_bytes();
        self.write_secret(IDENTITY_ACCOUNT_NAME, secret.as_slice())
    }

    fn load_peer_secret(
        &self,
    ) -> Result<Option<PeerSecret>, IdentityStoreError> {
        let Some(secret_bytes) = self.read_secret(PEER_SECRET_ACCOUNT_NAME)?
        else {
            return Ok(None);
        };
        read_stored_peer_secret(&secret_bytes).map(Some)
    }

    fn save_peer_secret(
        &self,
        secret: &[u8; PEER_SECRET_LENGTH],
    ) -> Result<(), IdentityStoreError> {
        self.write_secret(PEER_SECRET_ACCOUNT_NAME, secret)
    }

    fn forget_identity(&self) -> Result<(), IdentityStoreError> {
        self.delete_secret(IDENTITY_ACCOUNT_NAME)
    }

    fn forget_peer_secret(&self) -> Result<(), IdentityStoreError> {
        self.delete_secret(PEER_SECRET_ACCOUNT_NAME)
    }

    fn load_agent_credential(
        &self,
    ) -> Result<Option<Zeroizing<Vec<u8>>>, IdentityStoreError> {
        let stored = self.read_secret(AGENT_CREDENTIAL_ACCOUNT_NAME)?;
        Ok(stored.map(Zeroizing::new))
    }

    fn save_agent_credential(
        &self,
        encoded: &[u8],
    ) -> Result<(), IdentityStoreError> {
        self.write_secret(AGENT_CREDENTIAL_ACCOUNT_NAME, encoded)
    }

    fn forget_agent_credential(&self) -> Result<(), IdentityStoreError> {
        self.delete_secret(AGENT_CREDENTIAL_ACCOUNT_NAME)
    }
}

fn describe_keychain_error(error: &KeychainError) -> IdentityStoreError {
    IdentityStoreError::Keychain(error.to_string())
}

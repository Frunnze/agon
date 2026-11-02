use std::fmt;

use chacha20poly1305::aead::Aead;
use chacha20poly1305::{Key, KeyInit, XChaCha20Poly1305, XNonce};
use zeroize::Zeroizing;

use crate::error::SecurityError;
use crate::identity::KEY_LENGTH;
use crate::random_source::random_bytes;

const NONCE_LENGTH: usize = 24;

pub struct WorkspaceKey {
    key_bytes: Zeroizing<[u8; KEY_LENGTH]>,
}

impl WorkspaceKey {
    pub fn generate() -> Result<Self, SecurityError> {
        Ok(Self {
            key_bytes: random_bytes::<KEY_LENGTH>()?,
        })
    }

    pub fn from_bytes(key_bytes: &[u8]) -> Result<Self, SecurityError> {
        let fixed_key_bytes: [u8; KEY_LENGTH] = key_bytes
            .try_into()
            .map_err(|_| SecurityError::InvalidKey)?;
        Ok(Self {
            key_bytes: Zeroizing::new(fixed_key_bytes),
        })
    }

    #[must_use]
    pub fn to_bytes(&self) -> Zeroizing<[u8; KEY_LENGTH]> {
        self.key_bytes.clone()
    }

    pub fn encrypt(&self, plaintext: &[u8]) -> Result<Vec<u8>, SecurityError> {
        let nonce_bytes = random_bytes::<NONCE_LENGTH>()?;
        let nonce = XNonce::from(*nonce_bytes);

        let ciphertext = self
            .cipher()
            .encrypt(&nonce, plaintext)
            .map_err(|_| SecurityError::EncryptionFailed)?;

        Ok([nonce_bytes.as_slice(), ciphertext.as_slice()].concat())
    }

    pub fn decrypt(&self, encrypted: &[u8]) -> Result<Vec<u8>, SecurityError> {
        let (nonce_bytes, ciphertext) = encrypted
            .split_at_checked(NONCE_LENGTH)
            .ok_or(SecurityError::DecryptionFailed)?;
        let nonce = XNonce::try_from(nonce_bytes)
            .map_err(|_| SecurityError::DecryptionFailed)?;

        self.cipher()
            .decrypt(&nonce, ciphertext)
            .map_err(|_| SecurityError::DecryptionFailed)
    }

    fn cipher(&self) -> XChaCha20Poly1305 {
        let key: &Key = (&*self.key_bytes).into();
        XChaCha20Poly1305::new(key)
    }
}

impl fmt::Debug for WorkspaceKey {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("WorkspaceKey")
            .finish_non_exhaustive()
    }
}

mod sealed_text;
mod workspace_key;

use crypto_box::PublicKey as SealingPublicKey;
use rand_core::OsRng;

use crate::error::SecurityError;
use crate::identity::DeviceIdentity;

pub use sealed_text::{SEALED_TEXT_PREFIX, open_text, seal_text};
pub use workspace_key::WorkspaceKey;

pub fn seal_for(
    recipient_sealing_key: &[u8],
    plaintext: &[u8],
) -> Result<Vec<u8>, SecurityError> {
    let recipient_key = SealingPublicKey::from_slice(recipient_sealing_key)
        .map_err(|_| SecurityError::InvalidKey)?;

    recipient_key
        .seal(&mut OsRng, plaintext)
        .map_err(|_| SecurityError::EncryptionFailed)
}

pub fn open_sealed(
    recipient: &DeviceIdentity,
    sealed: &[u8],
) -> Result<Vec<u8>, SecurityError> {
    recipient
        .sealing_secret_key()
        .unseal(sealed)
        .map_err(|_| SecurityError::DecryptionFailed)
}

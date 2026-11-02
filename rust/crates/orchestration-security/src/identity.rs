use crypto_box::SecretKey as SealingSecretKey;
use ed25519_dalek::{Signature, Signer, SigningKey, VerifyingKey};
use orchestration_core::identifiers::DeviceId;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use zeroize::Zeroizing;

use crate::error::SecurityError;
use crate::random_source::random_bytes;

pub const KEY_LENGTH: usize = 32;
pub const IDENTITY_SECRET_LENGTH: usize = KEY_LENGTH + KEY_LENGTH;
const DEVICE_ID_DIGEST_PREFIX_LENGTH: usize = 16;

pub type IdentitySecret = Zeroizing<[u8; IDENTITY_SECRET_LENGTH]>;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PublicIdentity {
    pub device_id: DeviceId,
    pub signing_public_key: Vec<u8>,
    pub sealing_public_key: Vec<u8>,
}

#[derive(Debug)]
pub struct DeviceIdentity {
    signing_key: SigningKey,
    sealing_key: SealingSecretKey,
}

impl DeviceIdentity {
    pub fn generate() -> Result<Self, SecurityError> {
        let secret = random_bytes::<IDENTITY_SECRET_LENGTH>()?;
        Self::from_secret_bytes(secret.as_slice())
    }

    pub fn from_secret_bytes(
        secret_bytes: &[u8],
    ) -> Result<Self, SecurityError> {
        if secret_bytes.len() != IDENTITY_SECRET_LENGTH {
            return Err(SecurityError::InvalidKey);
        }

        let (signing_seed, sealing_seed) = secret_bytes.split_at(KEY_LENGTH);
        let signing_key = SigningKey::try_from(signing_seed)
            .map_err(|_| SecurityError::InvalidKey)?;
        let sealing_key = SealingSecretKey::from_slice(sealing_seed)
            .map_err(|_| SecurityError::InvalidKey)?;

        Ok(Self {
            signing_key,
            sealing_key,
        })
    }

    #[must_use]
    pub fn secret_bytes(&self) -> IdentitySecret {
        let mut secret = Zeroizing::new([0_u8; IDENTITY_SECRET_LENGTH]);
        let sealing_seed = Zeroizing::new(self.sealing_key.to_bytes());

        let (signing_part, sealing_part) = secret.split_at_mut(KEY_LENGTH);
        signing_part.copy_from_slice(self.signing_key.as_bytes());
        sealing_part.copy_from_slice(sealing_seed.as_slice());

        secret
    }

    #[must_use]
    pub fn public_identity(&self) -> PublicIdentity {
        let signing_public_key = self.signing_key.verifying_key().to_bytes();
        let sealing_public_key = self.sealing_key.public_key().to_bytes();

        PublicIdentity {
            device_id: device_id_for(&signing_public_key),
            signing_public_key: signing_public_key.to_vec(),
            sealing_public_key: sealing_public_key.to_vec(),
        }
    }

    #[must_use]
    pub fn device_id(&self) -> DeviceId {
        let signing_public_key = self.signing_key.verifying_key().to_bytes();
        device_id_for(&signing_public_key)
    }

    #[must_use]
    pub fn sign(&self, message: &[u8]) -> Vec<u8> {
        let signature: Signature = self.signing_key.sign(message);
        signature.to_bytes().to_vec()
    }

    pub(crate) fn sealing_secret_key(&self) -> &SealingSecretKey {
        &self.sealing_key
    }
}

pub fn verify_signature(
    public_key: &[u8],
    message: &[u8],
    signature: &[u8],
) -> Result<(), SecurityError> {
    let verifying_key = VerifyingKey::try_from(public_key)
        .map_err(|_| SecurityError::InvalidKey)?;
    let parsed_signature = Signature::from_slice(signature)
        .map_err(|_| SecurityError::InvalidSignature)?;

    verifying_key
        .verify_strict(message, &parsed_signature)
        .map_err(|_| SecurityError::InvalidSignature)
}

#[must_use]
pub fn device_id_for(signing_public_key: &[u8]) -> DeviceId {
    let digest = Sha256::digest(signing_public_key);
    let digest_prefix = &digest[..DEVICE_ID_DIGEST_PREFIX_LENGTH];
    DeviceId(hex::encode(digest_prefix))
}

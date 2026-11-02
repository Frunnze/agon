use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::canonical_message::encode_canonical_message;
use crate::error::SecurityError;
use crate::identity::{DeviceIdentity, verify_signature};
use crate::pairing::pairing_code::PairingCode;
use crate::pairing::word_list::FINGERPRINT_WORD_LIST;

pub const FINGERPRINT_WORD_COUNT: usize = 4;
const WORDS_DOMAIN: &str = "agents-orchestration/pairing-words/1";
const APPROVAL_DOMAIN: &str = "agents-orchestration/pairing-approval/1";

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct PairingPublicKeys {
    pub signing_public_key: Vec<u8>,
    pub sealing_public_key: Vec<u8>,
}

impl PairingPublicKeys {
    #[must_use]
    pub fn of_identity(identity: &DeviceIdentity) -> Self {
        let public_identity = identity.public_identity();
        Self {
            signing_public_key: public_identity.signing_public_key,
            sealing_public_key: public_identity.sealing_public_key,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PairingTranscript {
    pub code: PairingCode,
    pub joiner: PairingPublicKeys,
    pub approver: PairingPublicKeys,
    pub joiner_nonce: Vec<u8>,
    pub approver_nonce: Vec<u8>,
}

impl PairingTranscript {
    #[must_use]
    pub fn fingerprint_words(&self) -> [&'static str; FINGERPRINT_WORD_COUNT] {
        let digest = Sha256::digest(self.encode(WORDS_DOMAIN));

        std::array::from_fn(|position| {
            FINGERPRINT_WORD_LIST[usize::from(digest[position])]
        })
    }

    pub fn sign_approval(
        &self,
        approver_identity: &DeviceIdentity,
    ) -> Result<Vec<u8>, SecurityError> {
        let signer = PairingPublicKeys::of_identity(approver_identity);
        if signer != self.approver {
            return Err(SecurityError::SignerMismatch);
        }

        Ok(approver_identity.sign(&self.encode(APPROVAL_DOMAIN)))
    }

    pub fn verify_approval(
        &self,
        approval_signature: &[u8],
    ) -> Result<(), SecurityError> {
        verify_signature(
            &self.approver.signing_public_key,
            &self.encode(APPROVAL_DOMAIN),
            approval_signature,
        )
    }

    fn encode(&self, domain: &str) -> Vec<u8> {
        let canonical_code = String::from(self.code.clone());
        encode_canonical_message(
            domain,
            &[
                canonical_code.as_bytes(),
                &self.joiner.signing_public_key,
                &self.joiner.sealing_public_key,
                &self.approver.signing_public_key,
                &self.approver.sealing_public_key,
                &self.joiner_nonce,
                &self.approver_nonce,
            ],
        )
    }
}

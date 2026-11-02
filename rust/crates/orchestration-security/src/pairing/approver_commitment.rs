use sha2::{Digest, Sha256};

use crate::canonical_message::encode_canonical_message;
use crate::error::SecurityError;
use crate::pairing::pairing_code::PairingCode;
use crate::pairing::pairing_transcript::PairingPublicKeys;
use crate::random_source::random_bytes;

pub const PAIRING_NONCE_LENGTH: usize = 32;
pub const PAIRING_COMMITMENT_LENGTH: usize = 32;
const COMMITMENT_DOMAIN: &str = "agents-orchestration/pairing-commitment/1";

pub fn generate_pairing_nonce() -> Result<Vec<u8>, SecurityError> {
    let nonce = random_bytes::<PAIRING_NONCE_LENGTH>()?;
    Ok(nonce.to_vec())
}

#[must_use]
pub fn commit_to_approver_nonce(
    code: &PairingCode,
    approver: &PairingPublicKeys,
    approver_nonce: &[u8],
) -> Vec<u8> {
    let canonical_code = String::from(code.clone());
    let message = encode_canonical_message(
        COMMITMENT_DOMAIN,
        &[
            canonical_code.as_bytes(),
            &approver.signing_public_key,
            &approver.sealing_public_key,
            approver_nonce,
        ],
    );
    Sha256::digest(&message).to_vec()
}

pub fn verify_approver_commitment(
    code: &PairingCode,
    approver: &PairingPublicKeys,
    approver_nonce: &[u8],
    commitment: &[u8],
) -> Result<(), SecurityError> {
    if approver_nonce.len() != PAIRING_NONCE_LENGTH {
        return Err(SecurityError::MalformedPairingNonce);
    }

    let expected = commit_to_approver_nonce(code, approver, approver_nonce);
    if expected != commitment {
        return Err(SecurityError::PairingCommitmentMismatch);
    }
    Ok(())
}

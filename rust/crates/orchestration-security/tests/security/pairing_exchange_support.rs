use orchestration_security::error::SecurityError;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::pairing::{
    PAIRING_NONCE_LENGTH, PairingCode, PairingPublicKeys, PairingTranscript,
};
use proptest::collection::vec;
use proptest::prelude::*;

pub const CANONICAL_CODE_PATTERN: &str = "[0-9A-HJKMNP-TV-Z]{6}";

#[derive(Debug)]
pub struct TranscriptSides<'sides> {
    pub code: &'sides PairingCode,
    pub joiner: &'sides PairingPublicKeys,
    pub approver: &'sides PairingPublicKeys,
    pub joiner_nonce: &'sides [u8],
    pub approver_nonce: &'sides [u8],
}

pub fn nonce_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), PAIRING_NONCE_LENGTH)
}

pub fn keys_of(secret: &[u8]) -> Result<PairingPublicKeys, SecurityError> {
    let identity = DeviceIdentity::from_secret_bytes(secret)?;
    Ok(PairingPublicKeys::of_identity(&identity))
}

pub fn build_transcript(sides: &TranscriptSides<'_>) -> PairingTranscript {
    PairingTranscript {
        code: sides.code.clone(),
        joiner: sides.joiner.clone(),
        approver: sides.approver.clone(),
        joiner_nonce: sides.joiner_nonce.to_vec(),
        approver_nonce: sides.approver_nonce.to_vec(),
    }
}

use orchestration_core::identifiers::DeviceId;
use orchestration_security::pairing::{PairingPublicKeys, PairingTranscript};

use crate::error::ServerError;
use crate::stored_state::{JoinRecord, PairingRecord, StoredState};

const NONCES_NOT_EXCHANGED: &str =
    "the devices have not exchanged their pairing nonces yet";
const MISMATCHED_APPROVAL: &str =
    "the approval does not match the pairing transcript";

pub fn approver_keys_of(
    state: &StoredState,
    approver: &DeviceId,
) -> Result<PairingPublicKeys, ServerError> {
    let device = state
        .devices
        .get(approver)
        .ok_or(ServerError::NotFound("the trusted device"))?;
    Ok(PairingPublicKeys {
        signing_public_key: device.signing_public_key.clone(),
        sealing_public_key: device.sealing_public_key.clone(),
    })
}

pub fn require_signed_transcript(
    state: &StoredState,
    record: &PairingRecord,
    join: &JoinRecord,
    approval_signature: &[u8],
) -> Result<(), ServerError> {
    let (Some(joiner_nonce), Some(approver_nonce)) =
        (&join.joiner_nonce, &join.approver_nonce)
    else {
        return Err(ServerError::Conflict(NONCES_NOT_EXCHANGED.to_owned()));
    };

    let transcript = PairingTranscript {
        code: record.session.code.clone(),
        joiner: PairingPublicKeys {
            signing_public_key: join.registration.signing_public_key.clone(),
            sealing_public_key: join.registration.sealing_public_key.clone(),
        },
        approver: approver_keys_of(state, &record.started_by)?,
        joiner_nonce: joiner_nonce.clone(),
        approver_nonce: approver_nonce.clone(),
    };
    transcript
        .verify_approval(approval_signature)
        .map_err(|_| ServerError::Conflict(MISMATCHED_APPROVAL.to_owned()))
}

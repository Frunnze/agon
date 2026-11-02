use chrono::{DateTime, Utc};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::peer_address::ENDPOINT_PUBLIC_KEY_LENGTH;
use orchestration_core::server_group::{ServerMembership, ServerTerm};

use crate::canonical_message::{encode_canonical_message, encode_timestamp};
use crate::error::SecurityError;
use crate::identity::{DeviceIdentity, device_id_for, verify_signature};

const MEMBERSHIP_DOMAIN: &str = "orchestration-server-membership-v1";
const TERM_DOMAIN: &str = "orchestration-server-term-v1";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ServerKeys {
    pub signing_public_key: Vec<u8>,
    pub endpoint_public_key: [u8; ENDPOINT_PUBLIC_KEY_LENGTH],
}

#[must_use]
pub fn sign_server_membership(
    device: &DeviceIdentity,
    server_keys: &ServerKeys,
    joined_at: DateTime<Utc>,
) -> ServerMembership {
    let unsigned = ServerMembership {
        device_id: device.device_id(),
        server_id: device_id_for(&server_keys.signing_public_key),
        server_signing_public_key: server_keys.signing_public_key.clone(),
        endpoint_public_key: server_keys.endpoint_public_key,
        joined_at,
        signature: Vec::new(),
    };
    let signature = device.sign(&encode_membership(&unsigned));
    ServerMembership {
        signature,
        ..unsigned
    }
}

pub fn verify_server_membership(
    membership: &ServerMembership,
    device_signing_key: &[u8],
) -> Result<(), SecurityError> {
    if device_id_for(device_signing_key) != membership.device_id {
        return Err(SecurityError::SignerMismatch);
    }
    let server_id = device_id_for(&membership.server_signing_public_key);
    if server_id != membership.server_id {
        return Err(SecurityError::SignerMismatch);
    }
    let message = encode_membership(membership);
    verify_signature(device_signing_key, &message, &membership.signature)
}

#[must_use]
pub fn sign_server_term(
    device: &DeviceIdentity,
    number: u64,
    server_id: DeviceId,
) -> ServerTerm {
    let unsigned = ServerTerm {
        number,
        server_id,
        claimed_by: device.device_id(),
        signature: Vec::new(),
    };
    let signature = device.sign(&encode_term(&unsigned));
    ServerTerm {
        signature,
        ..unsigned
    }
}

pub fn verify_server_term(
    term: &ServerTerm,
    device_signing_key: &[u8],
) -> Result<(), SecurityError> {
    if device_id_for(device_signing_key) != term.claimed_by {
        return Err(SecurityError::SignerMismatch);
    }
    verify_signature(device_signing_key, &encode_term(term), &term.signature)
}

fn encode_membership(membership: &ServerMembership) -> Vec<u8> {
    encode_canonical_message(
        MEMBERSHIP_DOMAIN,
        &[
            membership.device_id.0.as_bytes(),
            membership.server_id.0.as_bytes(),
            &membership.server_signing_public_key,
            &membership.endpoint_public_key,
            &encode_timestamp(membership.joined_at),
        ],
    )
}

fn encode_term(term: &ServerTerm) -> Vec<u8> {
    encode_canonical_message(
        TERM_DOMAIN,
        &[
            &term.number.to_be_bytes(),
            term.server_id.0.as_bytes(),
            term.claimed_by.0.as_bytes(),
        ],
    )
}

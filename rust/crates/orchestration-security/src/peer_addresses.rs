use chrono::{DateTime, Utc};
use orchestration_core::peer_address::{
    ENDPOINT_PUBLIC_KEY_LENGTH, PeerAddress, SignedPeerAddress,
};
use zeroize::Zeroizing;

use crate::canonical_message::{encode_canonical_message, encode_timestamp};
use crate::error::SecurityError;
use crate::identity::{DeviceIdentity, device_id_for, verify_signature};
use crate::random_source::random_bytes;

const PEER_ADDRESS_DOMAIN: &str = "orchestration-peer-address-v1";

pub type PeerSecret = Zeroizing<[u8; ENDPOINT_PUBLIC_KEY_LENGTH]>;

pub fn generate_peer_secret() -> Result<PeerSecret, SecurityError> {
    random_bytes::<ENDPOINT_PUBLIC_KEY_LENGTH>()
}

#[must_use]
pub fn sign_peer_address(
    identity: &DeviceIdentity,
    address: &PeerAddress,
    published_at: DateTime<Utc>,
) -> SignedPeerAddress {
    let device_id = identity.device_id();
    let message = encode_address_message(&device_id.0, address, published_at);
    SignedPeerAddress {
        signature: identity.sign(&message),
        device_id,
        address: address.clone(),
        published_at,
    }
}

pub fn verify_peer_address(
    signed: &SignedPeerAddress,
    signer_key: &[u8],
) -> Result<(), SecurityError> {
    if device_id_for(signer_key) != signed.device_id {
        return Err(SecurityError::SignerMismatch);
    }
    let message = encode_address_message(
        &signed.device_id.0,
        &signed.address,
        signed.published_at,
    );
    verify_signature(signer_key, &message, &signed.signature)
}

fn encode_address_message(
    device_id: &str,
    address: &PeerAddress,
    published_at: DateTime<Utc>,
) -> Vec<u8> {
    let mut direct_addresses = Vec::new();
    for direct_address in &address.direct_addresses {
        direct_addresses.push(direct_address.to_string());
    }
    let joined_addresses = direct_addresses.join(",");
    let relay_url = address.relay_url.clone().unwrap_or_default();
    let has_relay = [u8::from(address.relay_url.is_some())];
    encode_canonical_message(
        PEER_ADDRESS_DOMAIN,
        &[
            device_id.as_bytes(),
            &address.endpoint_public_key,
            joined_addresses.as_bytes(),
            &has_relay,
            relay_url.as_bytes(),
            &encode_timestamp(published_at),
        ],
    )
}

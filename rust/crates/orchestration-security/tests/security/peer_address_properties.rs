use std::net::{Ipv4Addr, SocketAddr};

use orchestration_core::peer_address::{
    ENDPOINT_PUBLIC_KEY_LENGTH, PeerAddress,
};
use orchestration_security::error::SecurityError;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::peer_addresses::{
    generate_peer_secret, sign_peer_address, verify_peer_address,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::support::{
    distinct_secrets_strategy, moment_strategy, secret_strategy,
};

const MOST_DIRECT_ADDRESSES: usize = 4;

fn peer_address_strategy() -> impl Strategy<Value = PeerAddress> {
    let direct_address =
        (any::<[u8; 4]>(), any::<u16>()).prop_map(|(octets, port)| {
            SocketAddr::from((Ipv4Addr::from(octets), port))
        });
    (
        any::<[u8; ENDPOINT_PUBLIC_KEY_LENGTH]>(),
        vec(direct_address, 0..MOST_DIRECT_ADDRESSES),
        proptest::option::of("https://[a-z]{1,8}\\.example/"),
    )
        .prop_map(|(endpoint_public_key, direct_addresses, relay_url)| {
            PeerAddress {
                endpoint_public_key,
                direct_addresses,
                relay_url,
            }
        })
}

proptest! {
    #[test]
    fn test_sign_peer_address_property_verifies_with_the_signer_key(
        secret in secret_strategy(),
        address in peer_address_strategy(),
        published_at in moment_strategy(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;

        let signed = sign_peer_address(&identity, &address, published_at);

        prop_assert_eq!(&signed.address, &address);
        prop_assert_eq!(&signed.device_id, &identity.device_id());
        prop_assert_eq!(signed.published_at, published_at);
        prop_assert_eq!(verify_peer_address(&signed, &signer_key), Ok(()));
    }

    #[test]
    fn test_verify_peer_address_property_rejects_another_signer(
        (first_secret, second_secret) in distinct_secrets_strategy(),
        address in peer_address_strategy(),
        published_at in moment_strategy(),
    ) {
        let signer = DeviceIdentity::from_secret_bytes(&first_secret)?;
        let other = DeviceIdentity::from_secret_bytes(&second_secret)?;
        let other_key = other.public_identity().signing_public_key;

        let signed = sign_peer_address(&signer, &address, published_at);

        let verification = verify_peer_address(&signed, &other_key);
        prop_assert_eq!(verification, Err(SecurityError::SignerMismatch));
    }

    #[test]
    fn test_verify_peer_address_property_rejects_a_changed_address(
        secret in secret_strategy(),
        address in peer_address_strategy(),
        other_key in any::<[u8; ENDPOINT_PUBLIC_KEY_LENGTH]>(),
        published_at in moment_strategy(),
    ) {
        prop_assume!(other_key != address.endpoint_public_key);
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let mut signed = sign_peer_address(&identity, &address, published_at);

        signed.address.endpoint_public_key = other_key;

        let verification = verify_peer_address(&signed, &signer_key);
        prop_assert_eq!(verification, Err(SecurityError::InvalidSignature));
    }

    #[test]
    fn test_generate_peer_secret_property_never_repeats(
        _round in 0_u8..8,
    ) {
        let first = generate_peer_secret()?;
        let second = generate_peer_secret()?;

        prop_assert_ne!(first.as_slice(), second.as_slice());
    }
}

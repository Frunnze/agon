use orchestration_core::identifiers::DeviceId;
use orchestration_core::peer_address::ENDPOINT_PUBLIC_KEY_LENGTH;
use orchestration_security::error::SecurityError;
use orchestration_security::identity::{DeviceIdentity, device_id_for};
use orchestration_security::server_group::{
    ServerKeys, sign_server_membership, sign_server_term,
    verify_server_membership, verify_server_term,
};
use proptest::prelude::*;

use crate::support::{
    distinct_secrets_strategy, flip_bit, fuzz_bytes_strategy, moment_strategy,
    secret_strategy,
};

fn server_keys_for(
    server: &DeviceIdentity,
    endpoint_public_key: [u8; ENDPOINT_PUBLIC_KEY_LENGTH],
) -> ServerKeys {
    ServerKeys {
        signing_public_key: server.public_identity().signing_public_key,
        endpoint_public_key,
    }
}

proptest! {
    #[test]
    fn test_sign_server_membership_property_verifies_with_the_device_key(
        (device_secret, server_secret) in distinct_secrets_strategy(),
        endpoint_public_key in any::<[u8; ENDPOINT_PUBLIC_KEY_LENGTH]>(),
        joined_at in moment_strategy(),
    ) {
        let device = DeviceIdentity::from_secret_bytes(&device_secret)?;
        let server = DeviceIdentity::from_secret_bytes(&server_secret)?;
        let keys = server_keys_for(&server, endpoint_public_key);
        let device_key = device.public_identity().signing_public_key;

        let membership = sign_server_membership(&device, &keys, joined_at);

        prop_assert_eq!(&membership.device_id, &device.device_id());
        prop_assert_eq!(&membership.server_id, &server.device_id());
        prop_assert_eq!(membership.endpoint_public_key, endpoint_public_key);
        prop_assert_eq!(membership.joined_at, joined_at);
        prop_assert_eq!(
            verify_server_membership(&membership, &device_key),
            Ok(())
        );
    }

    #[test]
    fn test_verify_server_membership_property_refuses_another_device(
        (device_secret, other_secret) in distinct_secrets_strategy(),
        endpoint_public_key in any::<[u8; ENDPOINT_PUBLIC_KEY_LENGTH]>(),
        joined_at in moment_strategy(),
    ) {
        let device = DeviceIdentity::from_secret_bytes(&device_secret)?;
        let other = DeviceIdentity::from_secret_bytes(&other_secret)?;
        let keys = server_keys_for(&other, endpoint_public_key);
        let other_key = other.public_identity().signing_public_key;

        let membership = sign_server_membership(&device, &keys, joined_at);

        prop_assert_eq!(
            verify_server_membership(&membership, &other_key),
            Err(SecurityError::SignerMismatch)
        );
    }

    #[test]
    fn test_verify_server_membership_property_refuses_changed_keys(
        (device_secret, server_secret) in distinct_secrets_strategy(),
        endpoint_public_key in any::<[u8; ENDPOINT_PUBLIC_KEY_LENGTH]>(),
        joined_at in moment_strategy(),
        position in any::<usize>(),
        bit in any::<u8>(),
    ) {
        let device = DeviceIdentity::from_secret_bytes(&device_secret)?;
        let server = DeviceIdentity::from_secret_bytes(&server_secret)?;
        let keys = server_keys_for(&server, endpoint_public_key);
        let device_key = device.public_identity().signing_public_key;
        let membership = sign_server_membership(&device, &keys, joined_at);
        let changed_endpoint =
            flip_bit(&membership.endpoint_public_key, position, bit);
        let mut moved = membership.clone();
        moved.endpoint_public_key = changed_endpoint
            .try_into()
            .map_err(|_| TestCaseError::fail("the key keeps its length"))?;
        let mut swapped = membership.clone();
        swapped.server_signing_public_key = device_key.clone();

        prop_assert!(verify_server_membership(&moved, &device_key).is_err());
        prop_assert_eq!(
            verify_server_membership(&swapped, &device_key),
            Err(SecurityError::SignerMismatch)
        );
    }

    #[test]
    fn test_sign_server_term_property_verifies_and_binds_its_fields(
        secret in secret_strategy(),
        number in any::<u64>(),
        server_text in "[a-f0-9]{32}",
    ) {
        let device = DeviceIdentity::from_secret_bytes(&secret)?;
        let device_key = device.public_identity().signing_public_key;
        let server_id = DeviceId(server_text);

        let term = sign_server_term(&device, number, server_id.clone());
        let mut renumbered = term.clone();
        renumbered.number = number.wrapping_add(1);
        let mut moved = term.clone();
        moved.server_id = device.device_id();

        prop_assert_eq!(term.number, number);
        prop_assert_eq!(&term.server_id, &server_id);
        prop_assert_eq!(&term.claimed_by, &device_id_for(&device_key));
        prop_assert_eq!(verify_server_term(&term, &device_key), Ok(()));
        prop_assert!(verify_server_term(&renumbered, &device_key).is_err());
        prop_assert!(verify_server_term(&moved, &device_key).is_err());
    }

    #[test]
    fn test_verify_server_term_property_refuses_arbitrary_signatures(
        secret in secret_strategy(),
        number in any::<u64>(),
        signature in fuzz_bytes_strategy(),
    ) {
        let device = DeviceIdentity::from_secret_bytes(&secret)?;
        let device_key = device.public_identity().signing_public_key;
        let mut term = sign_server_term(&device, number, device.device_id());
        term.signature = signature;

        prop_assert!(verify_server_term(&term, &device_key).is_err());
    }
}

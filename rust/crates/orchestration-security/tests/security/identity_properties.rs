use orchestration_security::error::SecurityError;
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH, KEY_LENGTH, device_id_for,
    verify_signature,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::support::{
    distinct_secrets_strategy, flip_bit, message_strategy,
    non_empty_message_strategy, secret_strategy,
};

const DEVICE_ID_LENGTH: usize = 32;
const LONGEST_WRONG_SECRET: usize = 160;

proptest! {
    #[test]
    fn test_generate_property_signatures_verify_with_own_key(
        message in message_strategy(),
    ) {
        let identity = DeviceIdentity::generate()?;
        let signing_public_key = identity.public_identity().signing_public_key;

        let signature = identity.sign(&message);

        verify_signature(&signing_public_key, &message, &signature)?;
    }

    #[test]
    fn test_from_secret_bytes_property_rejects_wrong_length(
        secret in vec(any::<u8>(), 0..LONGEST_WRONG_SECRET),
    ) {
        prop_assume!(secret.len() != IDENTITY_SECRET_LENGTH);

        let restored = DeviceIdentity::from_secret_bytes(&secret);

        prop_assert_eq!(restored.err(), Some(SecurityError::InvalidKey));
    }

    #[test]
    fn test_secret_bytes_property_round_trips_through_from_secret_bytes(
        secret in secret_strategy(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let exported_secret = identity.secret_bytes();
        let restored =
            DeviceIdentity::from_secret_bytes(exported_secret.as_slice())?;

        prop_assert_eq!(exported_secret.as_slice(), secret.as_slice());
        let original_public_identity = identity.public_identity();
        prop_assert_eq!(restored.public_identity(), original_public_identity);
    }

    #[test]
    fn test_public_identity_property_device_id_derives_from_signing_key(
        secret in secret_strategy(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;

        let public_identity = identity.public_identity();

        let expected_device_id =
            device_id_for(&public_identity.signing_public_key);
        prop_assert_eq!(&public_identity.device_id, &expected_device_id);
        prop_assert_eq!(public_identity.signing_public_key.len(), KEY_LENGTH);
        prop_assert_eq!(public_identity.sealing_public_key.len(), KEY_LENGTH);
    }

    #[test]
    fn test_device_id_property_matches_public_identity(
        secret in secret_strategy(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;

        let device_id = identity.device_id();

        prop_assert_eq!(device_id, identity.public_identity().device_id);
    }

    #[test]
    fn test_sign_property_any_flipped_signature_bit_fails(
        secret in secret_strategy(),
        message in message_strategy(),
        position in any::<usize>(),
        bit in any::<u8>(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signing_public_key = identity.public_identity().signing_public_key;
        let signature = identity.sign(&message);

        let tampered_signature = flip_bit(&signature, position, bit);

        let verification = verify_signature(
            &signing_public_key,
            &message,
            &tampered_signature,
        );
        prop_assert_eq!(verification, Err(SecurityError::InvalidSignature));
    }

    #[test]
    fn test_verify_signature_property_any_flipped_message_bit_fails(
        secret in secret_strategy(),
        message in non_empty_message_strategy(),
        position in any::<usize>(),
        bit in any::<u8>(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signing_public_key = identity.public_identity().signing_public_key;
        let signature = identity.sign(&message);

        let tampered_message = flip_bit(&message, position, bit);

        let verification = verify_signature(
            &signing_public_key,
            &tampered_message,
            &signature,
        );
        prop_assert_eq!(verification, Err(SecurityError::InvalidSignature));
    }

    #[test]
    fn test_verify_signature_property_other_key_fails(
        (signer_secret, other_secret) in distinct_secrets_strategy(),
        message in message_strategy(),
    ) {
        let signer = DeviceIdentity::from_secret_bytes(&signer_secret)?;
        let other = DeviceIdentity::from_secret_bytes(&other_secret)?;
        let other_key = other.public_identity().signing_public_key;
        let signature = signer.sign(&message);

        let verification = verify_signature(&other_key, &message, &signature);

        prop_assert_eq!(verification, Err(SecurityError::InvalidSignature));
    }

    #[test]
    fn test_device_id_for_property_is_32_lowercase_hex_digits(
        key in message_strategy(),
    ) {
        let device_id = device_id_for(&key);

        prop_assert_eq!(device_id.0.len(), DEVICE_ID_LENGTH);
        let is_lowercase_hex = device_id.0.chars().all(|character| {
            character.is_ascii_digit() || ('a'..='f').contains(&character)
        });
        prop_assert!(is_lowercase_hex);
    }
}

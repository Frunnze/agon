use orchestration_security::error::SecurityError;
use orchestration_security::identity::{DeviceIdentity, KEY_LENGTH};
use orchestration_security::sealing::{
    SEALED_TEXT_PREFIX, WorkspaceKey, open_sealed, open_text, seal_for,
    seal_text,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::support::{
    distinct_secrets_strategy, flip_bit, message_strategy, secret_strategy,
};

const LONGEST_WRONG_KEY: usize = 96;
const LOWERCASE_HEX_DIGITS: &[char] = &[
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e',
    'f',
];

fn workspace_key_bytes_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), KEY_LENGTH)
}

fn distinct_workspace_keys_strategy()
-> impl Strategy<Value = (Vec<u8>, Vec<u8>)> {
    (
        workspace_key_bytes_strategy(),
        workspace_key_bytes_strategy(),
    )
        .prop_filter("keys must differ", |(first, second)| first != second)
}

fn wrong_length_key_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..LONGEST_WRONG_KEY)
        .prop_filter("length must be wrong", |key| key.len() != KEY_LENGTH)
}

fn replace_character(text: &str, position: usize, digit: char) -> String {
    let mut characters: Vec<char> = text.chars().collect();
    let replaced_position = position % characters.len();
    characters[replaced_position] = digit;
    characters.into_iter().collect()
}

proptest! {
    #[test]
    fn test_seal_for_property_open_sealed_recovers_plaintext(
        secret in secret_strategy(),
        plaintext in message_strategy(),
    ) {
        let recipient = DeviceIdentity::from_secret_bytes(&secret)?;
        let sealing_key = recipient.public_identity().sealing_public_key;

        let sealed = seal_for(&sealing_key, &plaintext)?;

        prop_assert_eq!(open_sealed(&recipient, &sealed)?, plaintext);
    }

    #[test]
    fn test_seal_for_property_rejects_wrong_key_length(
        recipient_key in wrong_length_key_strategy(),
        plaintext in message_strategy(),
    ) {
        let sealed = seal_for(&recipient_key, &plaintext);

        prop_assert_eq!(sealed, Err(SecurityError::InvalidKey));
    }

    #[test]
    fn test_open_sealed_property_any_flipped_bit_fails(
        secret in secret_strategy(),
        plaintext in message_strategy(),
        position in any::<usize>(),
        bit in any::<u8>(),
    ) {
        let recipient = DeviceIdentity::from_secret_bytes(&secret)?;
        let sealing_key = recipient.public_identity().sealing_public_key;
        let sealed = seal_for(&sealing_key, &plaintext)?;

        let tampered = flip_bit(&sealed, position, bit);

        let opened = open_sealed(&recipient, &tampered);
        prop_assert_eq!(opened, Err(SecurityError::DecryptionFailed));
    }

    #[test]
    fn test_open_sealed_property_other_identity_fails(
        (recipient_secret, other_secret) in distinct_secrets_strategy(),
        plaintext in message_strategy(),
    ) {
        let recipient = DeviceIdentity::from_secret_bytes(&recipient_secret)?;
        let other = DeviceIdentity::from_secret_bytes(&other_secret)?;
        let sealing_key = recipient.public_identity().sealing_public_key;
        let sealed = seal_for(&sealing_key, &plaintext)?;

        let opened = open_sealed(&other, &sealed);

        prop_assert_eq!(opened, Err(SecurityError::DecryptionFailed));
    }

    #[test]
    fn test_generate_property_encrypt_then_decrypt_round_trips(
        plaintext in message_strategy(),
    ) {
        let workspace_key = WorkspaceKey::generate()?;

        let encrypted = workspace_key.encrypt(&plaintext)?;

        prop_assert_eq!(workspace_key.decrypt(&encrypted)?, plaintext);
    }

    #[test]
    fn test_encrypt_property_same_plaintext_never_repeats_ciphertext(
        key_bytes in workspace_key_bytes_strategy(),
        plaintext in message_strategy(),
    ) {
        let workspace_key = WorkspaceKey::from_bytes(&key_bytes)?;

        let first = workspace_key.encrypt(&plaintext)?;
        let second = workspace_key.encrypt(&plaintext)?;

        prop_assert_ne!(first, second);
    }

    #[test]
    fn test_decrypt_property_any_flipped_bit_fails(
        key_bytes in workspace_key_bytes_strategy(),
        plaintext in message_strategy(),
        position in any::<usize>(),
        bit in any::<u8>(),
    ) {
        let workspace_key = WorkspaceKey::from_bytes(&key_bytes)?;
        let encrypted = workspace_key.encrypt(&plaintext)?;

        let tampered = flip_bit(&encrypted, position, bit);

        let decrypted = workspace_key.decrypt(&tampered);
        prop_assert_eq!(decrypted, Err(SecurityError::DecryptionFailed));
    }

    #[test]
    fn test_decrypt_property_other_key_fails(
        (key_bytes, other_key_bytes) in distinct_workspace_keys_strategy(),
        plaintext in message_strategy(),
    ) {
        let workspace_key = WorkspaceKey::from_bytes(&key_bytes)?;
        let other_key = WorkspaceKey::from_bytes(&other_key_bytes)?;
        let encrypted = workspace_key.encrypt(&plaintext)?;

        let decrypted = other_key.decrypt(&encrypted);

        prop_assert_eq!(decrypted, Err(SecurityError::DecryptionFailed));
    }

    #[test]
    fn test_to_bytes_property_round_trips_through_from_bytes(
        key_bytes in workspace_key_bytes_strategy(),
    ) {
        let workspace_key = WorkspaceKey::from_bytes(&key_bytes)?;

        let exported = workspace_key.to_bytes();

        prop_assert_eq!(exported.as_slice(), key_bytes.as_slice());
    }

    #[test]
    fn test_from_bytes_property_rejects_wrong_length(
        key_bytes in wrong_length_key_strategy(),
    ) {
        let workspace_key = WorkspaceKey::from_bytes(&key_bytes);

        prop_assert_eq!(workspace_key.err(), Some(SecurityError::InvalidKey));
    }

    #[test]
    fn test_seal_text_property_open_text_round_trips(
        key_bytes in workspace_key_bytes_strategy(),
        text in any::<String>(),
    ) {
        let workspace_key = WorkspaceKey::from_bytes(&key_bytes)?;

        let sealed = seal_text(&workspace_key, &text)?;

        prop_assert_eq!(open_text(&workspace_key, &sealed)?, text);
    }

    #[test]
    fn test_seal_text_property_is_prefixed_lowercase_hex(
        key_bytes in workspace_key_bytes_strategy(),
        text in any::<String>(),
    ) {
        let workspace_key = WorkspaceKey::from_bytes(&key_bytes)?;

        let sealed = seal_text(&workspace_key, &text)?;

        let encoded = sealed.strip_prefix(SEALED_TEXT_PREFIX);
        prop_assert!(encoded.is_some());
        let is_lowercase_hex = encoded
            .unwrap_or_default()
            .chars()
            .all(|character| LOWERCASE_HEX_DIGITS.contains(&character));
        prop_assert!(is_lowercase_hex);
    }

    #[test]
    fn test_open_text_property_any_changed_character_fails(
        key_bytes in workspace_key_bytes_strategy(),
        text in any::<String>(),
        position in any::<usize>(),
        digit in proptest::sample::select(LOWERCASE_HEX_DIGITS),
    ) {
        let workspace_key = WorkspaceKey::from_bytes(&key_bytes)?;
        let sealed = seal_text(&workspace_key, &text)?;
        let tampered = replace_character(&sealed, position, digit);
        prop_assume!(tampered != sealed);

        let opened = open_text(&workspace_key, &tampered);

        prop_assert!(matches!(
            opened,
            Err(
                SecurityError::DecryptionFailed
                    | SecurityError::MalformedSealedText
            )
        ));
    }

    #[test]
    fn test_open_text_property_other_key_fails(
        (key_bytes, other_key_bytes) in distinct_workspace_keys_strategy(),
        text in any::<String>(),
    ) {
        let workspace_key = WorkspaceKey::from_bytes(&key_bytes)?;
        let other_key = WorkspaceKey::from_bytes(&other_key_bytes)?;
        let sealed = seal_text(&workspace_key, &text)?;

        let opened = open_text(&other_key, &sealed);

        prop_assert_eq!(opened, Err(SecurityError::DecryptionFailed));
    }
}

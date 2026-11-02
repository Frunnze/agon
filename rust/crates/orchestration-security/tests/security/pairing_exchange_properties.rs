use orchestration_security::error::SecurityError;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::pairing::{
    FINGERPRINT_WORD_COUNT, FINGERPRINT_WORD_LIST, PAIRING_COMMITMENT_LENGTH,
    PAIRING_NONCE_LENGTH, PairingCode, PairingPublicKeys,
    commit_to_approver_nonce, generate_pairing_nonce,
    verify_approver_commitment,
};
use proptest::prelude::*;

use crate::pairing_exchange_support::{
    CANONICAL_CODE_PATTERN, TranscriptSides, build_transcript, keys_of,
    nonce_strategy,
};
use crate::support::{distinct_secrets_strategy, flip_bit, secret_strategy};

const SHORT_NONCE_LIMIT: usize = PAIRING_NONCE_LENGTH;

proptest! {
    #[test]
    fn test_of_identity_property_keys_are_the_identity_public_keys(
        secret in secret_strategy(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let public_identity = identity.public_identity();

        let keys = PairingPublicKeys::of_identity(&identity);

        prop_assert_eq!(
            keys.signing_public_key,
            public_identity.signing_public_key
        );
        prop_assert_eq!(
            keys.sealing_public_key,
            public_identity.sealing_public_key
        );
    }

    #[test]
    fn test_generate_pairing_nonce_property_fresh_nonces_of_nonce_length(
        _attempt in any::<u8>(),
    ) {
        let first_nonce = generate_pairing_nonce()?;
        let second_nonce = generate_pairing_nonce()?;

        prop_assert_eq!(first_nonce.len(), PAIRING_NONCE_LENGTH);
        prop_assert_eq!(second_nonce.len(), PAIRING_NONCE_LENGTH);
        prop_assert_ne!(first_nonce, second_nonce);
    }

    #[test]
    fn test_commit_to_approver_nonce_property_opens_with_its_own_nonce(
        symbols in CANONICAL_CODE_PATTERN,
        approver_secret in secret_strategy(),
        approver_nonce in nonce_strategy(),
    ) {
        let code = PairingCode::parse(&symbols)?;
        let approver = keys_of(&approver_secret)?;

        let commitment =
            commit_to_approver_nonce(&code, &approver, &approver_nonce);
        let opened = verify_approver_commitment(
            &code,
            &approver,
            &approver_nonce,
            &commitment,
        );

        prop_assert_eq!(commitment.len(), PAIRING_COMMITMENT_LENGTH);
        prop_assert_eq!(opened, Ok(()));
    }

    #[test]
    fn test_verify_approver_commitment_property_replay_on_other_code_fails(
        first_symbols in CANONICAL_CODE_PATTERN,
        second_symbols in CANONICAL_CODE_PATTERN,
        approver_secret in secret_strategy(),
        approver_nonce in nonce_strategy(),
    ) {
        let first_code = PairingCode::parse(&first_symbols)?;
        let second_code = PairingCode::parse(&second_symbols)?;
        prop_assume!(first_code != second_code);
        let approver = keys_of(&approver_secret)?;
        let old_commitment =
            commit_to_approver_nonce(&first_code, &approver, &approver_nonce);

        let replayed = verify_approver_commitment(
            &second_code,
            &approver,
            &approver_nonce,
            &old_commitment,
        );

        let expected = Err(SecurityError::PairingCommitmentMismatch);
        prop_assert_eq!(replayed, expected);
    }

    #[test]
    fn test_verify_approver_commitment_property_other_nonce_fails(
        symbols in CANONICAL_CODE_PATTERN,
        approver_secret in secret_strategy(),
        committed_nonce in nonce_strategy(),
        revealed_nonce in nonce_strategy(),
    ) {
        prop_assume!(committed_nonce != revealed_nonce);
        let code = PairingCode::parse(&symbols)?;
        let approver = keys_of(&approver_secret)?;
        let commitment =
            commit_to_approver_nonce(&code, &approver, &committed_nonce);

        let opened = verify_approver_commitment(
            &code,
            &approver,
            &revealed_nonce,
            &commitment,
        );

        let expected = Err(SecurityError::PairingCommitmentMismatch);
        prop_assert_eq!(opened, expected);
    }

    #[test]
    fn test_verify_approver_commitment_property_other_keys_fail(
        symbols in CANONICAL_CODE_PATTERN,
        (approver_secret, substitute_secret) in distinct_secrets_strategy(),
        approver_nonce in nonce_strategy(),
    ) {
        let code = PairingCode::parse(&symbols)?;
        let approver = keys_of(&approver_secret)?;
        let substitute = keys_of(&substitute_secret)?;
        let commitment =
            commit_to_approver_nonce(&code, &approver, &approver_nonce);

        let opened = verify_approver_commitment(
            &code,
            &substitute,
            &approver_nonce,
            &commitment,
        );

        let expected = Err(SecurityError::PairingCommitmentMismatch);
        prop_assert_eq!(opened, expected);
    }

    #[test]
    fn test_verify_approver_commitment_property_short_nonce_is_malformed(
        symbols in CANONICAL_CODE_PATTERN,
        approver_secret in secret_strategy(),
        short_nonce in proptest::collection::vec(
            any::<u8>(),
            0..SHORT_NONCE_LIMIT,
        ),
    ) {
        let code = PairingCode::parse(&symbols)?;
        let approver = keys_of(&approver_secret)?;
        let commitment =
            commit_to_approver_nonce(&code, &approver, &short_nonce);

        let opened = verify_approver_commitment(
            &code,
            &approver,
            &short_nonce,
            &commitment,
        );

        prop_assert_eq!(opened, Err(SecurityError::MalformedPairingNonce));
    }

    #[test]
    fn test_fingerprint_words_property_honest_devices_show_the_same_words(
        symbols in CANONICAL_CODE_PATTERN,
        (approver_secret, joiner_secret) in distinct_secrets_strategy(),
        approver_nonce in nonce_strategy(),
        joiner_nonce in nonce_strategy(),
    ) {
        let code = PairingCode::parse(&symbols)?;
        let approver_identity =
            DeviceIdentity::from_secret_bytes(&approver_secret)?;
        let joiner_identity =
            DeviceIdentity::from_secret_bytes(&joiner_secret)?;
        let approver = PairingPublicKeys::of_identity(&approver_identity);
        let joiner = PairingPublicKeys::of_identity(&joiner_identity);
        let offered_commitment =
            commit_to_approver_nonce(&code, &approver, &approver_nonce);

        verify_approver_commitment(
            &code,
            &approver,
            &approver_nonce,
            &offered_commitment,
        )?;
        let joiner_view = build_transcript(&TranscriptSides {
            code: &code,
            joiner: &joiner,
            approver: &approver,
            joiner_nonce: &joiner_nonce,
            approver_nonce: &approver_nonce,
        });
        let approver_view = build_transcript(&TranscriptSides {
            code: &PairingCode::parse(&code.display())?,
            joiner: &keys_of(&joiner_secret)?,
            approver: &keys_of(&approver_secret)?,
            joiner_nonce: &joiner_nonce,
            approver_nonce: &approver_nonce,
        });

        let joiner_words = joiner_view.fingerprint_words();
        let approver_words = approver_view.fingerprint_words();

        prop_assert_eq!(joiner_words, approver_words);
        prop_assert_eq!(joiner_words.len(), FINGERPRINT_WORD_COUNT);
        for word in joiner_words {
            prop_assert!(FINGERPRINT_WORD_LIST.contains(&word));
        }
    }

    #[test]
    fn test_fingerprint_words_property_changed_nonce_changes_words(
        symbols in CANONICAL_CODE_PATTERN,
        (approver_secret, joiner_secret) in distinct_secrets_strategy(),
        approver_nonce in nonce_strategy(),
        joiner_nonce in nonce_strategy(),
        position in any::<usize>(),
        bit in any::<u8>(),
    ) {
        let code = PairingCode::parse(&symbols)?;
        let joiner = keys_of(&joiner_secret)?;
        let approver = keys_of(&approver_secret)?;
        let substituted_nonce = flip_bit(&joiner_nonce, position, bit);
        let original_sides = TranscriptSides {
            code: &code,
            joiner: &joiner,
            approver: &approver,
            joiner_nonce: &joiner_nonce,
            approver_nonce: &approver_nonce,
        };
        let original = build_transcript(&original_sides);
        let substituted = build_transcript(&TranscriptSides {
            joiner_nonce: &substituted_nonce,
            ..original_sides
        });

        let original_words = original.fingerprint_words();
        let substituted_words = substituted.fingerprint_words();

        prop_assert_ne!(original_words, substituted_words);
    }
}

use orchestration_security::error::SecurityError;
use orchestration_security::pairing::{
    FINGERPRINT_WORD_COUNT, PairingCode, PairingPublicKeys,
    commit_to_approver_nonce, verify_approver_commitment,
};
use proptest::prelude::*;

use crate::pairing_exchange_support::{
    CANONICAL_CODE_PATTERN, TranscriptSides, build_transcript, keys_of,
    nonce_strategy,
};
use crate::support::secret_strategy;

const RELAY_CASES: u32 = 1024;

type ShownWords = [&'static str; FINGERPRINT_WORD_COUNT];

#[derive(Debug)]
struct RelayedDevices {
    code: PairingCode,
    joiner: PairingPublicKeys,
    approver: PairingPublicKeys,
    relay: PairingPublicKeys,
}

#[derive(Debug)]
struct RelayedNonces {
    joiner_nonce: Vec<u8>,
    approver_nonce: Vec<u8>,
    relay_nonce_toward_joiner: Vec<u8>,
    relay_nonce_toward_approver: Vec<u8>,
}

#[derive(Debug)]
struct RelayedWords {
    joiner_words: ShownWords,
    approver_words: ShownWords,
}

fn relay_with_substituted_keys(
    devices: &RelayedDevices,
    nonces: &RelayedNonces,
) -> Result<RelayedWords, SecurityError> {
    let relay_commitment = commit_to_approver_nonce(
        &devices.code,
        &devices.relay,
        &nonces.relay_nonce_toward_joiner,
    );
    verify_approver_commitment(
        &devices.code,
        &devices.relay,
        &nonces.relay_nonce_toward_joiner,
        &relay_commitment,
    )?;
    let joiner_view = build_transcript(&TranscriptSides {
        code: &devices.code,
        joiner: &devices.joiner,
        approver: &devices.relay,
        joiner_nonce: &nonces.joiner_nonce,
        approver_nonce: &nonces.relay_nonce_toward_joiner,
    });
    let approver_view = build_transcript(&TranscriptSides {
        code: &devices.code,
        joiner: &devices.relay,
        approver: &devices.approver,
        joiner_nonce: &nonces.relay_nonce_toward_approver,
        approver_nonce: &nonces.approver_nonce,
    });
    Ok(RelayedWords {
        joiner_words: joiner_view.fingerprint_words(),
        approver_words: approver_view.fingerprint_words(),
    })
}

fn relayed_devices_strategy() -> impl Strategy<Value = RelayedDevices> {
    (
        CANONICAL_CODE_PATTERN,
        secret_strategy(),
        secret_strategy(),
        secret_strategy(),
    )
        .prop_filter_map(
            "every secret makes keys",
            |(symbols, joiner_secret, approver_secret, relay_secret)| {
                Some(RelayedDevices {
                    code: PairingCode::parse(&symbols).ok()?,
                    joiner: keys_of(&joiner_secret).ok()?,
                    approver: keys_of(&approver_secret).ok()?,
                    relay: keys_of(&relay_secret).ok()?,
                })
            },
        )
}

fn relayed_nonces_strategy() -> impl Strategy<Value = RelayedNonces> {
    (
        nonce_strategy(),
        nonce_strategy(),
        nonce_strategy(),
        any::<bool>(),
    )
        .prop_map(
            |(
                joiner_nonce,
                approver_nonce,
                relay_nonce_toward_joiner,
                relay_copies_joiner_nonce,
            )| {
                let relay_nonce_toward_approver = if relay_copies_joiner_nonce
                {
                    joiner_nonce.clone()
                } else {
                    relay_nonce_toward_joiner.clone()
                };
                RelayedNonces {
                    joiner_nonce,
                    approver_nonce,
                    relay_nonce_toward_joiner,
                    relay_nonce_toward_approver,
                }
            },
        )
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RELAY_CASES))]

    #[test]
    fn test_fingerprint_words_property_relay_with_own_keys_shows_other_words(
        devices in relayed_devices_strategy(),
        nonces in relayed_nonces_strategy(),
    ) {
        prop_assume!(devices.relay != devices.joiner);
        prop_assume!(devices.relay != devices.approver);

        let relayed = relay_with_substituted_keys(&devices, &nonces)?;

        prop_assert_ne!(relayed.joiner_words, relayed.approver_words);
    }

    #[test]
    fn test_fingerprint_words_property_relay_passing_approver_keys_fails(
        devices in relayed_devices_strategy(),
        nonces in relayed_nonces_strategy(),
    ) {
        prop_assume!(devices.relay != devices.joiner);
        let joiner_view = build_transcript(&TranscriptSides {
            code: &devices.code,
            joiner: &devices.joiner,
            approver: &devices.approver,
            joiner_nonce: &nonces.joiner_nonce,
            approver_nonce: &nonces.approver_nonce,
        });
        let approver_view = build_transcript(&TranscriptSides {
            code: &devices.code,
            joiner: &devices.relay,
            approver: &devices.approver,
            joiner_nonce: &nonces.relay_nonce_toward_approver,
            approver_nonce: &nonces.approver_nonce,
        });

        let joiner_words = joiner_view.fingerprint_words();
        let approver_words = approver_view.fingerprint_words();

        prop_assert_ne!(joiner_words, approver_words);
    }

    #[test]
    fn test_verify_approver_commitment_property_relay_cannot_change_reveal(
        devices in relayed_devices_strategy(),
        nonces in relayed_nonces_strategy(),
    ) {
        prop_assume!(
            nonces.approver_nonce != nonces.relay_nonce_toward_joiner
        );
        let relay_commitment = commit_to_approver_nonce(
            &devices.code,
            &devices.relay,
            &nonces.relay_nonce_toward_joiner,
        );

        let adapted_reveal = verify_approver_commitment(
            &devices.code,
            &devices.relay,
            &nonces.approver_nonce,
            &relay_commitment,
        );

        let expected = Err(SecurityError::PairingCommitmentMismatch);
        prop_assert_eq!(adapted_reveal, expected);
    }
}

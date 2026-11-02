use orchestration_security::error::SecurityError;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::pairing::{
    PairingCode, PairingPublicKeys, PairingTranscript,
    commit_to_approver_nonce, verify_approver_commitment,
};
use proptest::prelude::*;

use crate::pairing_exchange_support::{
    CANONICAL_CODE_PATTERN, TranscriptSides, build_transcript, keys_of,
    nonce_strategy,
};
use crate::support::{
    distinct_secrets_strategy, flip_bit, fuzz_bytes_strategy,
    non_empty_message_strategy,
};

const TRANSCRIPT_PART_COUNT: usize = 7;
const DEFINED_COMMITMENT_ERRORS: [SecurityError; 2] = [
    SecurityError::MalformedPairingNonce,
    SecurityError::PairingCommitmentMismatch,
];
const DEFINED_SIGNATURE_ERRORS: [SecurityError; 2] =
    [SecurityError::InvalidKey, SecurityError::InvalidSignature];

#[derive(Debug)]
struct SignedPairing {
    transcript: PairingTranscript,
    approver_identity: DeviceIdentity,
    joiner_identity: DeviceIdentity,
}

fn signed_pairing_strategy() -> impl Strategy<Value = SignedPairing> {
    (
        CANONICAL_CODE_PATTERN,
        distinct_secrets_strategy(),
        nonce_strategy(),
        nonce_strategy(),
    )
        .prop_filter_map(
            "every secret makes an identity",
            |(symbols, secrets, joiner_nonce, approver_nonce)| {
                let (approver_secret, joiner_secret) = secrets;
                let approver_identity =
                    DeviceIdentity::from_secret_bytes(&approver_secret)
                        .ok()?;
                let joiner_identity =
                    DeviceIdentity::from_secret_bytes(&joiner_secret).ok()?;
                let transcript = build_transcript(&TranscriptSides {
                    code: &PairingCode::parse(&symbols).ok()?,
                    joiner: &PairingPublicKeys::of_identity(&joiner_identity),
                    approver: &PairingPublicKeys::of_identity(
                        &approver_identity,
                    ),
                    joiner_nonce: &joiner_nonce,
                    approver_nonce: &approver_nonce,
                });
                Some(SignedPairing {
                    transcript,
                    approver_identity,
                    joiner_identity,
                })
            },
        )
}

fn tamper_with_part(
    transcript: &PairingTranscript,
    part: usize,
    position: usize,
    bit: u8,
) -> Result<PairingTranscript, SecurityError> {
    let mut tampered = transcript.clone();
    match part {
        0 => tampered.code = PairingCode::parse(&next_code(transcript))?,
        1 => {
            tampered.joiner.signing_public_key =
                flip_bit(&transcript.joiner.signing_public_key, position, bit);
        }
        2 => {
            tampered.joiner.sealing_public_key =
                flip_bit(&transcript.joiner.sealing_public_key, position, bit);
        }
        3 => {
            tampered.approver.signing_public_key = flip_bit(
                &transcript.approver.signing_public_key,
                position,
                bit,
            );
        }
        4 => {
            tampered.approver.sealing_public_key = flip_bit(
                &transcript.approver.sealing_public_key,
                position,
                bit,
            );
        }
        5 => {
            tampered.joiner_nonce =
                flip_bit(&transcript.joiner_nonce, position, bit);
        }
        _ => {
            tampered.approver_nonce =
                flip_bit(&transcript.approver_nonce, position, bit);
        }
    }
    Ok(tampered)
}

fn next_code(transcript: &PairingTranscript) -> String {
    let canonical = String::from(transcript.code.clone());
    let replaced = if canonical.starts_with('0') { "1" } else { "0" };
    format!("{replaced}{}", &canonical[1..])
}

proptest! {
    #[test]
    fn test_sign_approval_property_signature_verifies_for_its_transcript(
        signed in signed_pairing_strategy(),
    ) {
        let signature =
            signed.transcript.sign_approval(&signed.approver_identity)?;

        let verified = signed.transcript.verify_approval(&signature);

        prop_assert_eq!(verified, Ok(()));
    }

    #[test]
    fn test_verify_approval_property_any_changed_part_is_refused(
        signed in signed_pairing_strategy(),
        part in 0..TRANSCRIPT_PART_COUNT,
        position in any::<usize>(),
        bit in any::<u8>(),
    ) {
        let signature =
            signed.transcript.sign_approval(&signed.approver_identity)?;
        let tampered =
            tamper_with_part(&signed.transcript, part, position, bit)?;

        let verified = tampered.verify_approval(&signature);

        prop_assert!(verified.is_err());
    }

    #[test]
    fn test_sign_approval_property_only_the_approver_may_sign(
        signed in signed_pairing_strategy(),
    ) {
        let signed_by_joiner =
            signed.transcript.sign_approval(&signed.joiner_identity);

        prop_assert_eq!(signed_by_joiner, Err(SecurityError::SignerMismatch));
    }

    #[test]
    fn test_verify_approval_property_old_approval_fails_for_new_nonce(
        signed in signed_pairing_strategy(),
        fresh_approver_nonce in nonce_strategy(),
    ) {
        prop_assume!(fresh_approver_nonce != signed.transcript.approver_nonce);
        let old_signature =
            signed.transcript.sign_approval(&signed.approver_identity)?;
        let mut new_attempt = signed.transcript.clone();
        new_attempt.approver_nonce = fresh_approver_nonce;

        let replayed = new_attempt.verify_approval(&old_signature);

        prop_assert_eq!(replayed, Err(SecurityError::InvalidSignature));
    }

    #[test]
    fn test_verify_approval_property_fuzzed_signature_gives_defined_error(
        signed in signed_pairing_strategy(),
        fuzzed_signature in fuzz_bytes_strategy(),
        fuzzed_key in non_empty_message_strategy(),
    ) {
        let mut fuzzed_transcript = signed.transcript.clone();
        fuzzed_transcript.approver.signing_public_key = fuzzed_key;

        let verified = fuzzed_transcript.verify_approval(&fuzzed_signature);

        let Err(problem) = verified else {
            return Err(TestCaseError::fail("a fuzzed signature verified"));
        };
        prop_assert!(DEFINED_SIGNATURE_ERRORS.contains(&problem));
    }

    #[test]
    fn test_verify_approver_commitment_property_fuzz_gives_defined_error(
        symbols in CANONICAL_CODE_PATTERN,
        (approver_secret, _other_secret) in distinct_secrets_strategy(),
        fuzzed_nonce in fuzz_bytes_strategy(),
        fuzzed_commitment in fuzz_bytes_strategy(),
    ) {
        let code = PairingCode::parse(&symbols)?;
        let approver = keys_of(&approver_secret)?;
        let honest_commitment =
            commit_to_approver_nonce(&code, &approver, &fuzzed_nonce);

        let opened = verify_approver_commitment(
            &code,
            &approver,
            &fuzzed_nonce,
            &fuzzed_commitment,
        );

        prop_assume!(fuzzed_commitment != honest_commitment);
        let Err(problem) = opened else {
            return Err(TestCaseError::fail("a fuzzed commitment opened"));
        };
        prop_assert!(DEFINED_COMMITMENT_ERRORS.contains(&problem));
    }
}

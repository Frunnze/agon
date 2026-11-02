use orchestration_core::approval::SignedDecision;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::workflow::{SignatureState, WorkflowSignature};
use orchestration_security::audit::{AuditEntry, verify_chain};
use orchestration_security::decisions::verify_decision;
use orchestration_security::documents::signature_state;
use orchestration_security::error::SecurityError;
use orchestration_security::identity::verify_signature;
use orchestration_security::request_signing::{
    RequestSignature, verify_request,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::support::{
    approval_request_strategy, decision_strategy, fuzz_bytes_strategy,
    message_strategy, moment_strategy, short_text_strategy,
};

const LONGEST_FUZZ_CHAIN: usize = 4;

fn audit_entry_strategy() -> impl Strategy<Value = AuditEntry> {
    (
        any::<usize>(),
        moment_strategy(),
        any::<String>(),
        any::<String>(),
        any::<String>(),
        any::<String>(),
        fuzz_bytes_strategy(),
    )
        .prop_map(
            |(index, at, device, event, previous_hash, hash, signature)| {
                AuditEntry {
                    index,
                    at,
                    device_id: DeviceId(device),
                    event,
                    detail: None,
                    previous_hash,
                    hash,
                    signature,
                }
            },
        )
}

proptest! {
    #[test]
    fn test_verify_signature_property_arbitrary_input_gives_defined_error(
        public_key in fuzz_bytes_strategy(),
        message in fuzz_bytes_strategy(),
        signature in fuzz_bytes_strategy(),
    ) {
        let verification = verify_signature(&public_key, &message, &signature);

        prop_assert!(matches!(
            verification,
            Err(SecurityError::InvalidKey | SecurityError::InvalidSignature)
        ));
    }

    #[test]
    fn test_verify_decision_property_arbitrary_input_gives_defined_error(
        request in approval_request_strategy(),
        decision in decision_strategy(),
        decided_by in any::<String>(),
        decided_at in moment_strategy(),
        signature in fuzz_bytes_strategy(),
        signer_key in fuzz_bytes_strategy(),
    ) {
        let signed = SignedDecision {
            decision,
            decided_by: DeviceId(decided_by),
            decided_at,
            signature,
        };

        let verification = verify_decision(&request, &signed, &signer_key);

        prop_assert!(matches!(
            verification,
            Err(
                SecurityError::SignerMismatch
                    | SecurityError::InvalidKey
                    | SecurityError::InvalidSignature
            )
        ));
    }

    #[test]
    fn test_signature_state_property_arbitrary_signature_is_never_signed(
        signed_by in any::<String>(),
        signature in fuzz_bytes_strategy(),
        document in any::<String>(),
        signer_key in proptest::option::of(fuzz_bytes_strategy()),
    ) {
        let workflow_signature = WorkflowSignature {
            signed_by: DeviceId(signed_by),
            signature,
            signed_document: document.clone(),
        };

        let state = signature_state(
            Some(&workflow_signature),
            &document,
            signer_key.as_deref(),
        );

        prop_assert_eq!(state, SignatureState::ChangedNotSigned);
    }

    #[test]
    fn test_verify_chain_property_arbitrary_entries_fail_at_first_entry(
        chain in vec(audit_entry_strategy(), 1..LONGEST_FUZZ_CHAIN),
        signer_keys in proptest::collection::btree_map(
            any::<String>().prop_map(DeviceId),
            fuzz_bytes_strategy(),
            0..LONGEST_FUZZ_CHAIN,
        ),
    ) {
        let verification = verify_chain(&chain, &signer_keys);

        let is_broken_at_first_entry = matches!(
            verification,
            Err(SecurityError::AuditChainBroken { index: 0, .. })
        );
        prop_assert!(is_broken_at_first_entry);
    }

    #[test]
    fn test_verify_request_property_arbitrary_input_gives_defined_error(
        device_id in any::<String>(),
        timestamp in moment_strategy(),
        nonce in any::<[u8; 16]>(),
        signature in fuzz_bytes_strategy(),
        signer_key in fuzz_bytes_strategy(),
        method in any::<String>(),
        path in short_text_strategy(),
        body in message_strategy(),
        now in moment_strategy(),
    ) {
        let request_signature = RequestSignature {
            device_id: DeviceId(device_id),
            timestamp,
            nonce,
            signature,
        };

        let verification = verify_request(
            &request_signature,
            &signer_key,
            &method,
            &path,
            &body,
            now,
        );

        prop_assert!(matches!(
            verification,
            Err(
                SecurityError::SignerMismatch
                    | SecurityError::RequestTimestampOutsideWindow
                    | SecurityError::InvalidKey
                    | SecurityError::InvalidSignature
            )
        ));
    }
}

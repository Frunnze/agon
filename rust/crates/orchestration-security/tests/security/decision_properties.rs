use chrono::TimeDelta;
use orchestration_core::approval::ApprovalDecision;
use orchestration_security::decisions::{sign_decision, verify_decision};
use orchestration_security::error::SecurityError;
use orchestration_security::identity::DeviceIdentity;
use proptest::prelude::*;

use crate::support::{
    approval_request_strategy, decision_strategy, distinct_secrets_strategy,
    flip_bit, moment_strategy, secret_strategy,
};

fn opposite_decision(decision: ApprovalDecision) -> ApprovalDecision {
    match decision {
        ApprovalDecision::Approved => ApprovalDecision::Denied,
        ApprovalDecision::Denied => ApprovalDecision::Approved,
    }
}

proptest! {
    #[test]
    fn test_sign_decision_property_verifies_with_signer_key(
        secret in secret_strategy(),
        request in approval_request_strategy(),
        decision in decision_strategy(),
        decided_at in moment_strategy(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;

        let signed = sign_decision(&identity, &request, decision, decided_at)?;

        prop_assert_eq!(signed.decision, decision);
        prop_assert_eq!(&signed.decided_by, &identity.device_id());
        prop_assert_eq!(signed.decided_at, decided_at);
        let verification = verify_decision(&request, &signed, &signer_key);
        prop_assert_eq!(verification, Ok(()));
    }

    #[test]
    fn test_verify_decision_property_ignores_decision_stored_on_request(
        secret in secret_strategy(),
        request in approval_request_strategy(),
        decision in decision_strategy(),
        decided_at in moment_strategy(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let signed = sign_decision(&identity, &request, decision, decided_at)?;
        let mut decided_request = request.clone();
        decided_request.decision = Some(signed.clone());

        let verification =
            verify_decision(&decided_request, &signed, &signer_key);

        prop_assert_eq!(verification, Ok(()));
    }

    #[test]
    fn test_verify_decision_property_any_flipped_signature_bit_fails(
        secret in secret_strategy(),
        request in approval_request_strategy(),
        decision in decision_strategy(),
        decided_at in moment_strategy(),
        position in any::<usize>(),
        bit in any::<u8>(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let mut signed =
            sign_decision(&identity, &request, decision, decided_at)?;
        signed.signature = flip_bit(&signed.signature, position, bit);

        let verification = verify_decision(&request, &signed, &signer_key);

        prop_assert_eq!(verification, Err(SecurityError::InvalidSignature));
    }

    #[test]
    fn test_verify_decision_property_changed_decision_fails(
        secret in secret_strategy(),
        request in approval_request_strategy(),
        decision in decision_strategy(),
        decided_at in moment_strategy(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let mut signed =
            sign_decision(&identity, &request, decision, decided_at)?;
        signed.decision = opposite_decision(decision);

        let verification = verify_decision(&request, &signed, &signer_key);

        prop_assert_eq!(verification, Err(SecurityError::InvalidSignature));
    }

    #[test]
    fn test_verify_decision_property_changed_decision_time_fails(
        secret in secret_strategy(),
        request in approval_request_strategy(),
        decision in decision_strategy(),
        decided_at in moment_strategy(),
        shift_nanoseconds in 1_i64..i64::from(u32::MAX),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let mut signed =
            sign_decision(&identity, &request, decision, decided_at)?;
        signed.decided_at =
            decided_at + TimeDelta::nanoseconds(shift_nanoseconds);

        let verification = verify_decision(&request, &signed, &signer_key);

        prop_assert_eq!(verification, Err(SecurityError::InvalidSignature));
    }

    #[test]
    fn test_verify_decision_property_other_request_fails(
        secret in secret_strategy(),
        request in approval_request_strategy(),
        other_request in approval_request_strategy(),
        decision in decision_strategy(),
        decided_at in moment_strategy(),
    ) {
        prop_assume!(request != other_request);
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let signed = sign_decision(&identity, &request, decision, decided_at)?;

        let verification =
            verify_decision(&other_request, &signed, &signer_key);

        prop_assert_eq!(verification, Err(SecurityError::InvalidSignature));
    }

    #[test]
    fn test_verify_decision_property_other_signer_key_fails(
        (signer_secret, other_secret) in distinct_secrets_strategy(),
        request in approval_request_strategy(),
        decision in decision_strategy(),
        decided_at in moment_strategy(),
    ) {
        let signer = DeviceIdentity::from_secret_bytes(&signer_secret)?;
        let other = DeviceIdentity::from_secret_bytes(&other_secret)?;
        let other_key = other.public_identity().signing_public_key;
        let signed = sign_decision(&signer, &request, decision, decided_at)?;

        let verification = verify_decision(&request, &signed, &other_key);

        prop_assert_eq!(verification, Err(SecurityError::SignerMismatch));
    }
}

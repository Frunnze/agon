use orchestration_core::identifiers::DeviceId;
use orchestration_core::workflow::SignatureState;
use orchestration_security::documents::{sign_document, signature_state};
use orchestration_security::identity::DeviceIdentity;
use proptest::prelude::*;

use crate::support::{
    distinct_secrets_strategy, flip_bit, message_strategy, secret_strategy,
};

proptest! {
    #[test]
    fn test_sign_document_property_same_document_is_signed(
        secret in secret_strategy(),
        document in any::<String>(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;

        let signature = sign_document(&identity, &document);

        prop_assert_eq!(&signature.signed_by, &identity.device_id());
        prop_assert_eq!(&signature.signed_document, &document);
        let state =
            signature_state(Some(&signature), &document, Some(&signer_key));
        prop_assert_eq!(state, SignatureState::Signed);
    }

    #[test]
    fn test_signature_state_property_absent_signature_is_not_signed_yet(
        document in any::<String>(),
        signer_key in proptest::option::of(message_strategy()),
    ) {
        let state = signature_state(None, &document, signer_key.as_deref());

        prop_assert_eq!(state, SignatureState::NotSignedYet);
    }

    #[test]
    fn test_signature_state_property_changed_document_is_changed_not_signed(
        secret in secret_strategy(),
        document in any::<String>(),
        current_document in any::<String>(),
    ) {
        prop_assume!(document != current_document);
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let signature = sign_document(&identity, &document);

        let state = signature_state(
            Some(&signature),
            &current_document,
            Some(&signer_key),
        );

        prop_assert_eq!(state, SignatureState::ChangedNotSigned);
    }

    #[test]
    fn test_signature_state_property_tampered_signature_is_changed_not_signed(
        secret in secret_strategy(),
        document in any::<String>(),
        position in any::<usize>(),
        bit in any::<u8>(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let mut signature = sign_document(&identity, &document);
        signature.signature = flip_bit(&signature.signature, position, bit);

        let state =
            signature_state(Some(&signature), &document, Some(&signer_key));

        prop_assert_eq!(state, SignatureState::ChangedNotSigned);
    }

    #[test]
    fn test_signature_state_property_other_signer_key_is_changed_not_signed(
        (signer_secret, other_secret) in distinct_secrets_strategy(),
        document in any::<String>(),
    ) {
        let signer = DeviceIdentity::from_secret_bytes(&signer_secret)?;
        let other = DeviceIdentity::from_secret_bytes(&other_secret)?;
        let other_key = other.public_identity().signing_public_key;
        let signature = sign_document(&signer, &document);

        let state =
            signature_state(Some(&signature), &document, Some(&other_key));

        prop_assert_eq!(state, SignatureState::ChangedNotSigned);
    }

    #[test]
    fn test_signature_state_property_relabelled_signer_is_changed_not_signed(
        secret in secret_strategy(),
        document in any::<String>(),
        claimed_signer in any::<String>(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let mut signature = sign_document(&identity, &document);
        prop_assume!(claimed_signer != signature.signed_by.0);
        signature.signed_by = DeviceId(claimed_signer);

        let state =
            signature_state(Some(&signature), &document, Some(&signer_key));

        prop_assert_eq!(state, SignatureState::ChangedNotSigned);
    }

    #[test]
    fn test_signature_state_property_unknown_signer_is_changed_not_signed(
        secret in secret_strategy(),
        document in any::<String>(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signature = sign_document(&identity, &document);

        let state = signature_state(Some(&signature), &document, None);

        prop_assert_eq!(state, SignatureState::ChangedNotSigned);
    }
}

use orchestration_security::error::SecurityError;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::request_signing::{
    REQUEST_NONCE_LENGTH, RequestHeaderValues, RequestSignature, sign_request,
    verify_request,
};
use proptest::prelude::*;

use crate::support::{
    message_strategy, moment_strategy, secret_strategy, short_text_strategy,
};

const SAMPLE_METHOD: &str = "GET";

proptest! {
    #[test]
    fn test_sign_request_property_identical_requests_get_distinct_nonces(
        secret in secret_strategy(),
        path in short_text_strategy(),
        body in message_strategy(),
        timestamp in moment_strategy(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;

        let first =
            sign_request(&identity, SAMPLE_METHOD, &path, timestamp, &body)?;
        let second =
            sign_request(&identity, SAMPLE_METHOD, &path, timestamp, &body)?;

        prop_assert_ne!(first.nonce, second.nonce);
        prop_assert_ne!(&first.signature, &second.signature);
        for signed in [&first, &second] {
            let verification = verify_request(
                signed,
                &signer_key,
                SAMPLE_METHOD,
                &path,
                &body,
                timestamp,
            );
            prop_assert_eq!(verification, Ok(()));
        }
    }

    #[test]
    fn test_verify_request_property_any_tampered_nonce_fails(
        secret in secret_strategy(),
        body in message_strategy(),
        timestamp in moment_strategy(),
        position in 0..REQUEST_NONCE_LENGTH,
        flip in 1_u8..=255,
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let mut signed =
            sign_request(&identity, SAMPLE_METHOD, "/runs", timestamp, &body)?;

        signed.nonce[position] ^= flip;

        let verification = verify_request(
            &signed,
            &signer_key,
            SAMPLE_METHOD,
            "/runs",
            &body,
            timestamp,
        );
        prop_assert_eq!(verification, Err(SecurityError::InvalidSignature));
    }

    #[test]
    fn test_from_header_values_property_rejects_malformed_nonces(
        secret in secret_strategy(),
        timestamp in moment_strategy(),
        nonce_text in prop_oneof![
            "[0-9a-f]{0,30}",
            "[0-9a-f]{34,40}",
            "[g-z]{32}",
        ],
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signed =
            sign_request(&identity, SAMPLE_METHOD, "/runs", timestamp, b"")?;
        let mut header_values = signed.to_header_values();

        header_values.nonce = nonce_text;

        let restored = RequestSignature::from_header_values(&header_values);
        prop_assert_eq!(restored, Err(SecurityError::MalformedRequestHeader));
    }

    #[test]
    fn test_from_header_values_property_round_trips_the_nonce(
        secret in secret_strategy(),
        timestamp in moment_strategy(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signed =
            sign_request(&identity, SAMPLE_METHOD, "/runs", timestamp, b"")?;

        let header_values: RequestHeaderValues = signed.to_header_values();

        prop_assert_eq!(header_values.nonce.len(), REQUEST_NONCE_LENGTH * 2);
        let restored = RequestSignature::from_header_values(&header_values)?;
        prop_assert_eq!(restored.nonce, signed.nonce);
    }
}

use chrono::TimeDelta;
use orchestration_security::error::SecurityError;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::request_signing::{
    RequestHeaderValues, RequestSignature, sign_request, verify_request,
};
use proptest::prelude::*;

use crate::support::{
    distinct_secrets_strategy, flip_bit, message_strategy, moment_strategy,
    non_empty_message_strategy, secret_strategy, short_text_strategy,
};

const METHOD_PATTERN: &str = "GET|POST|PUT|PATCH|DELETE";
const SAMPLE_METHOD: &str = "POST";
const SAMPLE_PATH: &str = "/runs";
const WINDOW_NANOSECONDS: i64 = 300_000_000_000;
const LONGEST_TEST_DELAY_NANOSECONDS: i64 = 1_000_000_000_000_000;
const SAMPLE_NONCE_TEXT: &str = "000102030405060708090a0b0c0d0e0f";

proptest! {
    #[test]
    fn test_sign_request_property_verifies_inside_five_minute_window(
        secret in secret_strategy(),
        method in METHOD_PATTERN,
        path in short_text_strategy(),
        body in message_strategy(),
        timestamp in moment_strategy(),
        offset in -WINDOW_NANOSECONDS..=WINDOW_NANOSECONDS,
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let now = timestamp + TimeDelta::nanoseconds(offset);

        let signature =
            sign_request(&identity, &method, &path, timestamp, &body)?;

        prop_assert_eq!(&signature.device_id, &identity.device_id());
        prop_assert_eq!(signature.timestamp, timestamp);
        let verification = verify_request(
            &signature,
            &signer_key,
            &method,
            &path,
            &body,
            now,
        );
        prop_assert_eq!(verification, Ok(()));
    }

    #[test]
    fn test_verify_request_property_rejects_timestamps_older_than_window(
        secret in secret_strategy(),
        body in message_strategy(),
        timestamp in moment_strategy(),
        delay in WINDOW_NANOSECONDS + 1..LONGEST_TEST_DELAY_NANOSECONDS,
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let signature = sign_request(
            &identity,
            SAMPLE_METHOD,
            SAMPLE_PATH,
            timestamp,
            &body,
        )?;
        let now = timestamp + TimeDelta::nanoseconds(delay);

        let verification = verify_request(
            &signature,
            &signer_key,
            SAMPLE_METHOD,
            SAMPLE_PATH,
            &body,
            now,
        );

        let expected = Err(SecurityError::RequestTimestampOutsideWindow);
        prop_assert_eq!(verification, expected);
    }

    #[test]
    fn test_verify_request_property_rejects_timestamps_ahead_of_window(
        secret in secret_strategy(),
        body in message_strategy(),
        timestamp in moment_strategy(),
        lead in WINDOW_NANOSECONDS + 1..LONGEST_TEST_DELAY_NANOSECONDS,
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let signature = sign_request(
            &identity,
            SAMPLE_METHOD,
            SAMPLE_PATH,
            timestamp,
            &body,
        )?;
        let now = timestamp - TimeDelta::nanoseconds(lead);

        let verification = verify_request(
            &signature,
            &signer_key,
            SAMPLE_METHOD,
            SAMPLE_PATH,
            &body,
            now,
        );

        let expected = Err(SecurityError::RequestTimestampOutsideWindow);
        prop_assert_eq!(verification, expected);
    }

    #[test]
    fn test_verify_request_property_any_flipped_body_bit_fails(
        secret in secret_strategy(),
        body in non_empty_message_strategy(),
        timestamp in moment_strategy(),
        position in any::<usize>(),
        bit in any::<u8>(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let signature = sign_request(
            &identity,
            SAMPLE_METHOD,
            SAMPLE_PATH,
            timestamp,
            &body,
        )?;
        let tampered_body = flip_bit(&body, position, bit);

        let verification = verify_request(
            &signature,
            &signer_key,
            SAMPLE_METHOD,
            SAMPLE_PATH,
            &tampered_body,
            timestamp,
        );

        prop_assert_eq!(verification, Err(SecurityError::InvalidSignature));
    }

    #[test]
    fn test_verify_request_property_changed_method_or_path_fails(
        secret in secret_strategy(),
        method in METHOD_PATTERN,
        path in short_text_strategy(),
        other_method in METHOD_PATTERN,
        other_path in short_text_strategy(),
        body in message_strategy(),
        timestamp in moment_strategy(),
    ) {
        prop_assume!(method != other_method || path != other_path);
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signer_key = identity.public_identity().signing_public_key;
        let signature =
            sign_request(&identity, &method, &path, timestamp, &body)?;

        let verification = verify_request(
            &signature,
            &signer_key,
            &other_method,
            &other_path,
            &body,
            timestamp,
        );

        prop_assert_eq!(verification, Err(SecurityError::InvalidSignature));
    }

    #[test]
    fn test_verify_request_property_other_signer_key_fails(
        (signer_secret, other_secret) in distinct_secrets_strategy(),
        body in message_strategy(),
        timestamp in moment_strategy(),
    ) {
        let signer = DeviceIdentity::from_secret_bytes(&signer_secret)?;
        let other = DeviceIdentity::from_secret_bytes(&other_secret)?;
        let other_key = other.public_identity().signing_public_key;
        let signature = sign_request(
            &signer,
            SAMPLE_METHOD,
            SAMPLE_PATH,
            timestamp,
            &body,
        )?;

        let verification = verify_request(
            &signature,
            &other_key,
            SAMPLE_METHOD,
            SAMPLE_PATH,
            &body,
            timestamp,
        );

        prop_assert_eq!(verification, Err(SecurityError::SignerMismatch));
    }

    #[test]
    fn test_to_header_values_property_round_trips_through_from_header_values(
        secret in secret_strategy(),
        body in message_strategy(),
        timestamp in moment_strategy(),
    ) {
        let identity = DeviceIdentity::from_secret_bytes(&secret)?;
        let signature = sign_request(
            &identity,
            SAMPLE_METHOD,
            SAMPLE_PATH,
            timestamp,
            &body,
        )?;

        let header_values = signature.to_header_values();

        let restored = RequestSignature::from_header_values(&header_values)?;
        prop_assert_eq!(restored, signature);
    }

    #[test]
    fn test_from_header_values_property_rejects_non_hex_signature(
        device_id in short_text_strategy(),
        timestamp in moment_strategy(),
        signature_text in "[g-zG-Z]{1,128}",
    ) {
        let header_values = RequestHeaderValues {
            device_id,
            timestamp: timestamp.to_rfc3339(),
            nonce: SAMPLE_NONCE_TEXT.to_owned(),
            signature: signature_text,
        };

        let restored = RequestSignature::from_header_values(&header_values);

        let expected = Err(SecurityError::MalformedRequestHeader);
        prop_assert_eq!(restored, expected);
    }

    #[test]
    fn test_from_header_values_property_rejects_malformed_timestamp(
        device_id in short_text_strategy(),
        timestamp_text in "[a-z0-9 :]{0,32}",
    ) {
        let header_values = RequestHeaderValues {
            device_id,
            timestamp: timestamp_text,
            nonce: SAMPLE_NONCE_TEXT.to_owned(),
            signature: String::new(),
        };

        let restored = RequestSignature::from_header_values(&header_values);

        let expected = Err(SecurityError::MalformedRequestHeader);
        prop_assert_eq!(restored, expected);
    }
}

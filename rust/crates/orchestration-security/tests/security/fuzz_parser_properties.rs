use orchestration_security::error::SecurityError;
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH, KEY_LENGTH,
};
use orchestration_security::pairing::PairingCode;
use orchestration_security::request_signing::{
    RequestHeaderValues, RequestSignature,
};
use orchestration_security::sealing::{
    SEALED_TEXT_PREFIX, WorkspaceKey, open_sealed, open_text, seal_for,
};
use proptest::prelude::*;

use crate::support::{fuzz_bytes_strategy, secret_strategy};

const WORKSPACE_KEY_BYTES: [u8; KEY_LENGTH] = [9; KEY_LENGTH];

proptest! {
    #[test]
    fn test_from_secret_bytes_property_arbitrary_input_never_panics(
        secret in fuzz_bytes_strategy(),
    ) {
        let restored = DeviceIdentity::from_secret_bytes(&secret);

        if secret.len() == IDENTITY_SECRET_LENGTH {
            prop_assert!(restored.is_ok());
        } else {
            prop_assert_eq!(restored.err(), Some(SecurityError::InvalidKey));
        }
    }

    #[test]
    fn test_parse_property_arbitrary_text_gives_defined_error(
        text in any::<String>(),
    ) {
        let parsed = PairingCode::parse(&text);

        if let Err(error) = parsed {
            prop_assert_eq!(error, SecurityError::MalformedPairingCode);
        }
    }

    #[test]
    fn test_try_from_property_arbitrary_json_text_never_panics(
        text in any::<String>(),
    ) {
        let json = serde_json::Value::String(text.clone()).to_string();

        let restored = serde_json::from_str::<PairingCode>(&json);

        prop_assert_eq!(restored.is_ok(), PairingCode::parse(&text).is_ok());
    }

    #[test]
    fn test_seal_for_property_arbitrary_key_gives_defined_error(
        recipient_key in fuzz_bytes_strategy(),
        plaintext in fuzz_bytes_strategy(),
    ) {
        let sealed = seal_for(&recipient_key, &plaintext);

        if let Err(error) = sealed {
            prop_assert_eq!(error, SecurityError::InvalidKey);
        }
    }

    #[test]
    fn test_open_sealed_property_arbitrary_bytes_give_defined_error(
        secret in secret_strategy(),
        sealed in fuzz_bytes_strategy(),
    ) {
        let recipient = DeviceIdentity::from_secret_bytes(&secret)?;

        let opened = open_sealed(&recipient, &sealed);

        prop_assert_eq!(opened, Err(SecurityError::DecryptionFailed));
    }

    #[test]
    fn test_decrypt_property_arbitrary_bytes_give_defined_error(
        encrypted in fuzz_bytes_strategy(),
    ) {
        let workspace_key = WorkspaceKey::from_bytes(&WORKSPACE_KEY_BYTES)?;

        let decrypted = workspace_key.decrypt(&encrypted);

        prop_assert_eq!(decrypted, Err(SecurityError::DecryptionFailed));
    }

    #[test]
    fn test_from_bytes_property_arbitrary_bytes_give_defined_error(
        key_bytes in fuzz_bytes_strategy(),
    ) {
        let workspace_key = WorkspaceKey::from_bytes(&key_bytes);

        if let Err(error) = workspace_key {
            prop_assert_eq!(error, SecurityError::InvalidKey);
        }
    }

    #[test]
    fn test_open_text_property_arbitrary_text_gives_defined_error(
        text in any::<String>(),
        encoded in "[0-9a-f]{0,200}",
    ) {
        let workspace_key = WorkspaceKey::from_bytes(&WORKSPACE_KEY_BYTES)?;
        let prefixed = format!("{SEALED_TEXT_PREFIX}{encoded}");

        let opened_text = open_text(&workspace_key, &text);
        let opened_prefixed = open_text(&workspace_key, &prefixed);

        for opened in [opened_text, opened_prefixed] {
            prop_assert!(matches!(
                opened,
                Err(
                    SecurityError::MalformedSealedText
                        | SecurityError::DecryptionFailed
                )
            ));
        }
    }

    #[test]
    fn test_from_header_values_property_arbitrary_text_gives_defined_error(
        device_id in any::<String>(),
        timestamp in any::<String>(),
        nonce in any::<String>(),
        signature in any::<String>(),
    ) {
        let header_values = RequestHeaderValues {
            device_id,
            timestamp,
            nonce,
            signature,
        };

        let restored = RequestSignature::from_header_values(&header_values);

        if let Err(error) = restored {
            prop_assert_eq!(error, SecurityError::MalformedRequestHeader);
        }
    }
}

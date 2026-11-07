use orchestration_api::accounts::{
    JoinAccepted, PairingCommitment, PairingNonce, PairingSessionCreated,
};
use proptest::prelude::*;
use uuid::Uuid;

use crate::account_strategies::{bytes, joining_device, text, timestamp};
use crate::wire_checks::{
    check_required_fields, check_round_trip, check_snake_case_keys,
};

const JOINING_DEVICE_OPTIONAL_FIELDS: [&str; 3] =
    ["kind", "joiner_nonce", "approver_nonce"];

fn pairing_session() -> impl Strategy<Value = PairingSessionCreated> {
    (text(), timestamp(), timestamp()).prop_map(
        |(code, started_at, expires_at)| PairingSessionCreated {
            code,
            started_at,
            expires_at,
        },
    )
}

fn join_accepted() -> impl Strategy<Value = JoinAccepted> {
    (any::<u128>(), bytes(), bytes(), bytes()).prop_map(
        |(number, signing, sealing, commitment)| JoinAccepted {
            join_id: Uuid::from_u128(number),
            approver_signing_public_key: signing,
            approver_sealing_public_key: sealing,
            approver_commitment: commitment,
        },
    )
}

proptest! {
    #[test]
    fn test_pairing_session_created_serde_property_survives_round_trip(
        session in pairing_session(),
    ) {
        check_round_trip(&session)?;
    }

    #[test]
    fn test_pairing_session_created_serde_property_writes_snake_case_keys(
        session in pairing_session(),
    ) {
        check_snake_case_keys(&session)?;
    }

    #[test]
    fn test_pairing_session_created_serde_property_needs_every_field(
        session in pairing_session(),
    ) {
        check_required_fields(&session, &[])?;
    }

    #[test]
    fn test_join_accepted_serde_property_survives_json_round_trip(
        accepted in join_accepted(),
    ) {
        check_round_trip(&accepted)?;
    }

    #[test]
    fn test_join_accepted_serde_property_writes_snake_case_keys(
        accepted in join_accepted(),
    ) {
        check_snake_case_keys(&accepted)?;
    }

    #[test]
    fn test_join_accepted_serde_property_needs_every_field(
        accepted in join_accepted(),
    ) {
        check_required_fields(&accepted, &[])?;
    }

    #[test]
    fn test_pairing_commitment_serde_property_survives_json_round_trip(
        commitment in bytes(),
    ) {
        check_round_trip(&PairingCommitment { commitment })?;
    }

    #[test]
    fn test_pairing_commitment_serde_property_writes_snake_case_keys(
        commitment in bytes(),
    ) {
        check_snake_case_keys(&PairingCommitment { commitment })?;
    }

    #[test]
    fn test_pairing_commitment_serde_property_needs_the_commitment(
        commitment in bytes(),
    ) {
        check_required_fields(&PairingCommitment { commitment }, &[])?;
    }

    #[test]
    fn test_pairing_nonce_serde_property_survives_json_round_trip(
        nonce in bytes(),
    ) {
        check_round_trip(&PairingNonce { nonce })?;
    }

    #[test]
    fn test_pairing_nonce_serde_property_writes_snake_case_keys(
        nonce in bytes(),
    ) {
        check_snake_case_keys(&PairingNonce { nonce })?;
    }

    #[test]
    fn test_pairing_nonce_serde_property_needs_the_nonce(nonce in bytes()) {
        check_required_fields(&PairingNonce { nonce }, &[])?;
    }

    #[test]
    fn test_joining_device_serde_property_survives_json_round_trip(
        joining in joining_device(),
    ) {
        check_round_trip(&joining)?;
    }

    #[test]
    fn test_joining_device_serde_property_writes_snake_case_keys(
        joining in joining_device(),
    ) {
        check_snake_case_keys(&joining)?;
    }

    #[test]
    fn test_joining_device_serde_property_only_kind_and_nonces_may_miss(
        joining in joining_device(),
    ) {
        check_required_fields(&joining, &JOINING_DEVICE_OPTIONAL_FIELDS)?;
    }
}

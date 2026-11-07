use orchestration_api::accounts::{
    ApprovePairingRequest, JoinStatus, PairingRequestView,
    PublishPeerAddressRequest, RevokeDeviceRequest, revocation_statement,
};
use orchestration_core::identifiers::DeviceId;
use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;
use serde_json::Value;

use crate::account_strategies::{
    account_view, bytes, joining_device, sealed_workspace_key,
    signed_peer_address, text, timestamp,
};
use crate::wire_checks::{
    check_required_fields, check_round_trip, check_snake_case_keys,
};

const STATE_FIELD: &str = "state";
const APPROVER_NONCE_FIELD: &str = "approver_nonce";
const JOINING_FIELD: &str = "joining";
const REVOCATION_PREFIX: &str = "orchestration-device-revocation-v1:";
const MAXIMUM_KEYS: usize = 3;

fn pairing_request_view() -> impl Strategy<Value = PairingRequestView> {
    (
        text(),
        timestamp(),
        timestamp(),
        option::of(joining_device()),
    )
        .prop_map(|(code, started_at, expires_at, joining)| {
            PairingRequestView {
                code,
                started_at,
                expires_at,
                joining,
            }
        })
}

fn approve_pairing_request() -> impl Strategy<Value = ApprovePairingRequest> {
    (vec(sealed_workspace_key(), 0..MAXIMUM_KEYS), bytes()).prop_map(
        |(sealed_workspace_keys, approval_signature)| ApprovePairingRequest {
            sealed_workspace_keys,
            approval_signature,
        },
    )
}

fn join_status() -> impl Strategy<Value = JoinStatus> {
    prop_oneof![
        option::of(bytes())
            .prop_map(|approver_nonce| JoinStatus::Waiting { approver_nonce }),
        (account_view(), bytes()).prop_map(|(account, approver_nonce)| {
            JoinStatus::Approved {
                account,
                approver_nonce,
            }
        }),
        Just(JoinStatus::Rejected),
        Just(JoinStatus::Expired),
    ]
}

fn optional_status_fields(status: &JoinStatus) -> Vec<&'static str> {
    if matches!(status, JoinStatus::Waiting { .. }) {
        return vec![APPROVER_NONCE_FIELD];
    }
    Vec::new()
}

fn read_state(status: &JoinStatus) -> Result<String, TestCaseError> {
    let encoded = serde_json::to_value(status)
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    let state = encoded.get(STATE_FIELD).and_then(Value::as_str);
    state
        .map(str::to_owned)
        .ok_or_else(|| TestCaseError::fail("a join status has a state"))
}

proptest! {
    #[test]
    fn test_pairing_request_view_serde_property_survives_round_trip(
        view in pairing_request_view(),
    ) {
        check_round_trip(&view)?;
    }

    #[test]
    fn test_pairing_request_view_serde_property_writes_snake_case_keys(
        view in pairing_request_view(),
    ) {
        check_snake_case_keys(&view)?;
    }

    #[test]
    fn test_pairing_request_view_serde_property_only_joining_may_miss(
        view in pairing_request_view(),
    ) {
        check_required_fields(&view, &[JOINING_FIELD])?;
    }

    #[test]
    fn test_approve_pairing_request_serde_property_survives_round_trip(
        request in approve_pairing_request(),
    ) {
        check_round_trip(&request)?;
    }

    #[test]
    fn test_approve_pairing_request_serde_property_writes_snake_case_keys(
        request in approve_pairing_request(),
    ) {
        check_snake_case_keys(&request)?;
    }

    #[test]
    fn test_approve_pairing_request_serde_property_needs_every_field(
        request in approve_pairing_request(),
    ) {
        check_required_fields(&request, &[])?;
    }

    #[test]
    fn test_join_status_serde_property_survives_json_round_trip(
        status in join_status(),
    ) {
        check_round_trip(&status)?;
    }

    #[test]
    fn test_join_status_serde_property_writes_snake_case_states(
        status in join_status(),
    ) {
        let state = read_state(&status)?;

        check_snake_case_keys(&status)?;
        let is_snake_case = !state.is_empty()
            && state.chars().all(|letter| letter.is_ascii_lowercase());
        prop_assert!(is_snake_case);
    }

    #[test]
    fn test_join_status_serde_property_needs_the_state_and_its_fields(
        status in join_status(),
    ) {
        check_required_fields(&status, &optional_status_fields(&status))?;
    }

    #[test]
    fn test_publish_peer_address_request_serde_property_round_trips(
        address in signed_peer_address(),
    ) {
        check_round_trip(&PublishPeerAddressRequest { address })?;
    }

    #[test]
    fn test_publish_peer_address_request_serde_property_snake_case_keys(
        address in signed_peer_address(),
    ) {
        check_snake_case_keys(&PublishPeerAddressRequest { address })?;
    }

    #[test]
    fn test_publish_peer_address_request_serde_property_needs_the_address(
        address in signed_peer_address(),
    ) {
        check_required_fields(&PublishPeerAddressRequest { address }, &[])?;
    }

    #[test]
    fn test_revoke_device_request_serde_property_survives_round_trip(
        approval_signature in bytes(),
    ) {
        check_round_trip(&RevokeDeviceRequest { approval_signature })?;
    }

    #[test]
    fn test_revoke_device_request_serde_property_writes_snake_case_keys(
        approval_signature in bytes(),
    ) {
        check_snake_case_keys(&RevokeDeviceRequest { approval_signature })?;
    }

    #[test]
    fn test_revoke_device_request_serde_property_needs_the_signature(
        approval_signature in bytes(),
    ) {
        let request = RevokeDeviceRequest { approval_signature };

        check_required_fields(&request, &[])?;
    }

    #[test]
    fn test_revocation_statement_property_is_the_versioned_prefix_and_id(
        device_text in "\\PC{0,40}",
    ) {
        let statement = revocation_statement(&DeviceId(device_text.clone()));

        let expected = format!("{REVOCATION_PREFIX}{device_text}");
        prop_assert_eq!(statement, expected.into_bytes());
    }

    #[test]
    fn test_revocation_statement_property_reads_back_the_device_id(
        device_text in "\\PC{0,40}",
    ) {
        let statement = revocation_statement(&DeviceId(device_text.clone()));

        let statement_text = String::from_utf8(statement).ok();
        let device_part = statement_text
            .as_deref()
            .and_then(|text| text.strip_prefix(REVOCATION_PREFIX));
        prop_assert_eq!(device_part, Some(device_text.as_str()));
    }
}

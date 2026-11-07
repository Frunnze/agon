use orchestration_api::accounts::{CreateAccountRequest, JoinRequest};
use proptest::prelude::*;

use crate::account_strategies::{
    account_view, bytes, device_registration, sealed_workspace_key, text,
    workspace_identifier,
};
use crate::wire_checks::{
    check_required_fields, check_round_trip, check_snake_case_keys,
};

const KIND_FIELD: &str = "kind";

fn create_account_request() -> impl Strategy<Value = CreateAccountRequest> {
    (
        device_registration(),
        workspace_identifier(),
        text(),
        bytes(),
        text(),
    )
        .prop_map(
            |(device, workspace_id, workspace_name, sealed, setup_code)| {
                CreateAccountRequest {
                    device,
                    workspace_id,
                    workspace_name,
                    sealed_workspace_key: sealed,
                    setup_code,
                }
            },
        )
}

fn join_request() -> impl Strategy<Value = JoinRequest> {
    (text(), device_registration())
        .prop_map(|(code, device)| JoinRequest { code, device })
}

proptest! {
    #[test]
    fn test_device_registration_serde_property_survives_json_round_trip(
        registration in device_registration(),
    ) {
        check_round_trip(&registration)?;
    }

    #[test]
    fn test_device_registration_serde_property_writes_snake_case_keys(
        registration in device_registration(),
    ) {
        check_snake_case_keys(&registration)?;
    }

    #[test]
    fn test_device_registration_serde_property_only_the_kind_may_be_missing(
        registration in device_registration(),
    ) {
        check_required_fields(&registration, &[KIND_FIELD])?;
    }

    #[test]
    fn test_sealed_workspace_key_serde_property_survives_json_round_trip(
        sealed in sealed_workspace_key(),
    ) {
        check_round_trip(&sealed)?;
    }

    #[test]
    fn test_sealed_workspace_key_serde_property_writes_snake_case_keys(
        sealed in sealed_workspace_key(),
    ) {
        check_snake_case_keys(&sealed)?;
    }

    #[test]
    fn test_sealed_workspace_key_serde_property_needs_every_field(
        sealed in sealed_workspace_key(),
    ) {
        check_required_fields(&sealed, &[])?;
    }

    #[test]
    fn test_create_account_request_serde_property_survives_json_round_trip(
        request in create_account_request(),
    ) {
        check_round_trip(&request)?;
    }

    #[test]
    fn test_create_account_request_serde_property_writes_snake_case_keys(
        request in create_account_request(),
    ) {
        check_snake_case_keys(&request)?;
    }

    #[test]
    fn test_create_account_request_serde_property_needs_every_field(
        request in create_account_request(),
    ) {
        check_required_fields(&request, &[])?;
    }

    #[test]
    fn test_account_view_serde_property_survives_json_round_trip(
        account in account_view(),
    ) {
        check_round_trip(&account)?;
    }

    #[test]
    fn test_account_view_serde_property_writes_snake_case_keys(
        account in account_view(),
    ) {
        check_snake_case_keys(&account)?;
    }

    #[test]
    fn test_account_view_serde_property_needs_every_field(
        account in account_view(),
    ) {
        check_required_fields(&account, &[])?;
    }

    #[test]
    fn test_join_request_serde_property_survives_json_round_trip(
        request in join_request(),
    ) {
        check_round_trip(&request)?;
    }

    #[test]
    fn test_join_request_serde_property_writes_snake_case_keys(
        request in join_request(),
    ) {
        check_snake_case_keys(&request)?;
    }

    #[test]
    fn test_join_request_serde_property_needs_every_field(
        request in join_request(),
    ) {
        check_required_fields(&request, &[])?;
    }
}

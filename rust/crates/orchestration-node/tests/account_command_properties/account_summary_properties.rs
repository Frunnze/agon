use proptest::prelude::*;
use serde_json::Value;

use crate::account_steps::{
    AccountRequest, NODE_CASES, collect_names, read_field_names, read_status,
    role_strategy, start_device_and_server, valid_name_strategy,
};
use crate::support::test_device::fail;

const SUMMARY_FIELDS: [&str; 2] = ["device", "workspaces"];
const SEALED_KEYS_FIELD: &str = "sealed_workspace_keys";
const THIS_DEVICE_KIND: &str = "computer";

fn read_workspace_identities(summary: &Value) -> Vec<(Value, Value)> {
    let mut identities = Vec::new();
    let workspaces = summary["workspaces"].as_array().cloned();
    for workspace in workspaces.unwrap_or_default() {
        identities.push((workspace["id"].clone(), workspace["name"].clone()));
    }
    identities
}

fn create_named_account(
    device_name: &str,
    workspace_name: &str,
    role: &str,
) -> Result<(AccountRequest, Value, Value), TestCaseError> {
    let (device, server) = start_device_and_server()?;
    let request = AccountRequest {
        device_name: device_name.to_owned(),
        workspace_name: workspace_name.to_owned(),
        role: role.to_owned(),
        ..AccountRequest::for_server(&server)?
    };
    let created = device.run(&request.to_command()).map_err(fail)?;
    let status = read_status(&device)?;
    Ok((request, created, status))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_summarize_account_property_keeps_sealed_keys_out_of_the_reply(
        device_name in valid_name_strategy(),
        workspace_name in valid_name_strategy(),
        role in role_strategy(),
    ) {
        let (_, created, status) =
            create_named_account(&device_name, &workspace_name, role)?;

        let expected_fields = collect_names(&SUMMARY_FIELDS);
        prop_assert_eq!(read_field_names(&created), expected_fields.clone());
        let shown_fields = read_field_names(&status["account"]);
        prop_assert_eq!(shown_fields, expected_fields);
        prop_assert!(!created.to_string().contains(SEALED_KEYS_FIELD));
        prop_assert!(!status.to_string().contains(SEALED_KEYS_FIELD));
    }

    #[test]
    fn test_summarize_account_property_mirrors_the_requested_account(
        device_name in valid_name_strategy(),
        workspace_name in valid_name_strategy(),
        role in role_strategy(),
    ) {
        let (request, created, _) =
            create_named_account(&device_name, &workspace_name, role)?;

        let device = &created["device"];
        prop_assert_eq!(&device["name"], &Value::from(request.device_name));
        prop_assert_eq!(&device["role"], &Value::from(request.role));
        prop_assert_eq!(&device["kind"], THIS_DEVICE_KIND);
        prop_assert_eq!(&device["revoked"], &Value::Bool(false));
        let identities = read_workspace_identities(&created);
        prop_assert_eq!(identities.len(), 1);
        let (workspace_id, shown_name) = identities[0].clone();
        prop_assert_eq!(shown_name, Value::from(request.workspace_name));
        let expected_workspaces = Value::from(vec![workspace_id]);
        prop_assert_eq!(&device["workspaces"], &expected_workspaces);
    }

    #[test]
    fn test_summarize_account_property_status_agrees_with_the_creation(
        device_name in valid_name_strategy(),
        workspace_name in valid_name_strategy(),
        role in role_strategy(),
    ) {
        let (_, created, status) =
            create_named_account(&device_name, &workspace_name, role)?;

        let shown = &status["account"];
        for field in ["id", "name", "role", "kind", "signing_public_key"] {
            prop_assert_eq!(
                &shown["device"][field],
                &created["device"][field],
                "{}",
                field
            );
        }
        prop_assert_eq!(
            read_workspace_identities(shown),
            read_workspace_identities(&created)
        );
    }
}

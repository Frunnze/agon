use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};

use crate::account_steps::{
    ACCOUNT_FILE_NAME, AccountRequest, HOSTED_SERVER_FILE_NAME, NODE_CASES,
    has_data_file, invalid_name_strategy, read_error, read_status,
    role_strategy, valid_name_strategy,
};
use crate::support::hosting_steps::{PEER_SCHEME_PREFIX, pick_free_port};
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const HOSTING_CASES: u32 = 2;
const ACCOUNT_EXISTS: &str = "this device already has an account";
const NAME_PROBLEM_PREFIX: &str = "a name ";
const LOCAL_ADDRESS_PREFIX: &str = "http://127.0.0.1:";
const HOSTING_NEEDS_CLIENT: &str =
    "only a client device can host the app server";
const RUNNER_ROLE: &str = "runner";
const CLIENT_ROLES: [&str; 2] = ["client", "client_and_runner"];

fn create_hosted_account_command(
    workspace_name: &str,
    device_name: &str,
    role: &str,
) -> Value {
    json!({
        "command": "create_hosted_account",
        "workspace_name": workspace_name,
        "device_name": device_name,
        "role": role,
    })
}

fn start_hosting_capable_device() -> Result<TestDevice, TestCaseError> {
    let port = pick_free_port().map_err(fail)?;
    TestDevice::start_hosting_on(port).map_err(fail)
}

fn assert_nothing_hosted(device: &TestDevice) -> Result<(), TestCaseError> {
    prop_assert!(!has_data_file(device, HOSTED_SERVER_FILE_NAME));
    let status = read_status(device)?;
    prop_assert_eq!(&status["hosted_server_address"], &Value::Null);
    Ok(())
}

fn name_pair_strategy() -> impl Strategy<Value = (String, String)> {
    prop_oneof![
        (invalid_name_strategy(), valid_name_strategy()),
        (valid_name_strategy(), invalid_name_strategy()),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_account_command_create_hosted_account_property_bad_names_fail(
        (workspace_name, device_name) in name_pair_strategy(),
        role in role_strategy(),
    ) {
        let device = start_hosting_capable_device()?;
        let command =
            create_hosted_account_command(&workspace_name, &device_name, role);

        let reply = device.send(&command);

        let error = read_error(&reply);
        prop_assert!(error.starts_with(NAME_PROBLEM_PREFIX), "{reply}");
        assert_nothing_hosted(&device)?;
        prop_assert!(!has_data_file(&device, ACCOUNT_FILE_NAME));
    }

    #[test]
    fn test_account_command_create_hosted_account_property_one_account_only(
        workspace_name in valid_name_strategy(),
        device_name in valid_name_strategy(),
        role in role_strategy(),
    ) {
        let device = start_hosting_capable_device()?;
        let server = TestServer::start().map_err(fail)?;
        let request = AccountRequest::for_server(&server)?;
        device.run(&request.to_command()).map_err(fail)?;
        let command =
            create_hosted_account_command(&workspace_name, &device_name, role);

        let reply = device.send(&command);

        prop_assert_eq!(read_error(&reply), ACCOUNT_EXISTS);
        assert_nothing_hosted(&device)?;
        let status = read_status(&device)?;
        let expected_address = Value::from(server.address.clone());
        prop_assert_eq!(&status["server_address"], &expected_address);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOSTING_CASES))]

    #[test]
    fn test_account_command_create_hosted_account_property_hosts_the_account(
        workspace_name in valid_name_strategy(),
        device_name in valid_name_strategy(),
        role in select(CLIENT_ROLES.to_vec()),
    ) {
        let device = start_hosting_capable_device()?;
        let command =
            create_hosted_account_command(&workspace_name, &device_name, role);

        let created = device.run(&command).map_err(fail)?;

        prop_assert_eq!(&created["device"]["name"], &Value::from(device_name));
        prop_assert_eq!(&created["device"]["role"], role);
        let workspace = &created["workspaces"][0];
        prop_assert_eq!(&workspace["name"], &Value::from(workspace_name));
        let status = read_status(&device)?;
        let hosted = status["hosted_server_address"].as_str();
        let hosted = hosted.unwrap_or_default();
        prop_assert!(hosted.starts_with(PEER_SCHEME_PREFIX), "{status}");
        let stored = status["server_address"].as_str().unwrap_or_default();
        prop_assert!(stored.starts_with(LOCAL_ADDRESS_PREFIX), "{status}");
        prop_assert_eq!(&status["device_id"], &created["device"]["id"]);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_account_command_create_hosted_account_property_refuses_runners(
        workspace_name in valid_name_strategy(),
        device_name in valid_name_strategy(),
    ) {
        let device = start_hosting_capable_device()?;
        let command = create_hosted_account_command(
            &workspace_name,
            &device_name,
            RUNNER_ROLE,
        );

        let reply = device.send(&command);

        prop_assert_eq!(read_error(&reply), HOSTING_NEEDS_CLIENT);
        assert_nothing_hosted(&device)?;
        prop_assert!(!has_data_file(&device, ACCOUNT_FILE_NAME));
        prop_assert_eq!(&read_status(&device)?["account"], &Value::Null);
    }
}

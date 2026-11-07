use proptest::prelude::*;
use serde_json::Value;

use crate::account_steps::{
    ACCOUNT_FILE_NAME, AccountRequest, NODE_CASES, WORKSPACE_NAME,
    has_data_file, invalid_name_strategy, read_error, read_status,
    role_strategy, start_device_and_server, start_device_with_account,
    valid_name_strategy,
};
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const ACCOUNT_EXISTS: &str = "this device already has an account";
const NAME_PROBLEM_PREFIX: &str = "a name ";

fn assert_refused_before_the_server(
    device: &TestDevice,
    server: &TestServer,
    reply: &Value,
) -> Result<(), TestCaseError> {
    let error = read_error(reply);
    prop_assert!(error.starts_with(NAME_PROBLEM_PREFIX), "{reply}");
    prop_assert!(server.recorded_requests().is_empty());
    prop_assert!(!has_data_file(device, ACCOUNT_FILE_NAME));
    let status = read_status(device)?;
    prop_assert_eq!(&status["device_id"], &Value::Null);
    prop_assert_eq!(&status["account"], &Value::Null);
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_ensure_new_account_property_refuses_an_invalid_device_name(
        device_name in invalid_name_strategy(),
        workspace_name in valid_name_strategy(),
    ) {
        let (device, server) = start_device_and_server()?;
        let mut request = AccountRequest::for_server(&server)?;
        request.device_name = device_name;
        request.workspace_name = workspace_name;

        let reply = device.send(&request.to_command());

        assert_refused_before_the_server(&device, &server, &reply)?;
    }

    #[test]
    fn test_ensure_new_account_property_refuses_an_invalid_workspace_name(
        device_name in valid_name_strategy(),
        workspace_name in invalid_name_strategy(),
    ) {
        let (device, server) = start_device_and_server()?;
        let mut request = AccountRequest::for_server(&server)?;
        request.device_name = device_name;
        request.workspace_name = workspace_name;

        let reply = device.send(&request.to_command());

        assert_refused_before_the_server(&device, &server, &reply)?;
    }

    #[test]
    fn test_ensure_new_account_property_refuses_a_second_account(
        device_name in valid_name_strategy(),
        workspace_name in valid_name_strategy(),
        role in role_strategy(),
    ) {
        let (device, server, created) = start_device_with_account()?;
        let other_server = TestServer::start().map_err(fail)?;
        let mut request = AccountRequest::for_server(&other_server)?;
        request.device_name = device_name;
        request.workspace_name = workspace_name;
        request.role = role.to_owned();
        let requests_before = server.recorded_requests().len();

        let reply = device.send(&request.to_command());

        prop_assert_eq!(read_error(&reply), ACCOUNT_EXISTS);
        prop_assert!(other_server.recorded_requests().is_empty());
        prop_assert_eq!(server.recorded_requests().len(), requests_before);
        let status = read_status(&device)?;
        let shown_device = &status["account"]["device"];
        prop_assert_eq!(&shown_device["id"], &created["device"]["id"]);
        prop_assert_eq!(&shown_device["name"], &created["device"]["name"]);
        prop_assert_eq!(
            &status["account"]["workspaces"][0]["name"],
            &Value::from(WORKSPACE_NAME)
        );
    }
}

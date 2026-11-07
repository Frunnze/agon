use proptest::prelude::*;
use serde_json::{Value, json};

use crate::account_steps::{
    ACCOUNT_FILE_NAME, AccountRequest, NODE_CASES, SERVER_FILE_NAME,
    has_data_file, read_status, start_device_with_account,
};
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const MOST_FORGETTINGS: usize = 4;
const FORGOTTEN_WHEN_EMPTY: [&str; 4] =
    ["server_address", "device_id", "account", "pending_join"];

fn forget_this_device(device: &TestDevice) -> Result<Value, TestCaseError> {
    device
        .run(&json!({ "command": "forget_this_device" }))
        .map_err(fail)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_account_command_forget_this_device_property_empties_the_status(
        stops_server in any::<bool>(),
    ) {
        let (device, server, _) = start_device_with_account()?;
        if stops_server {
            server.stop().map_err(fail)?;
        }

        let forgotten = forget_this_device(&device)?;

        prop_assert_eq!(forgotten, Value::Null);
        let status = read_status(&device)?;
        prop_assert_eq!(&status["server_reachable"], &Value::Bool(false));
        for field in FORGOTTEN_WHEN_EMPTY {
            prop_assert_eq!(&status[field], &Value::Null, "{}", field);
        }
        prop_assert!(!has_data_file(&device, ACCOUNT_FILE_NAME));
        prop_assert!(!has_data_file(&device, SERVER_FILE_NAME));
    }

    #[test]
    fn test_account_command_forget_this_device_property_can_be_repeated(
        forgettings in 1..MOST_FORGETTINGS,
    ) {
        let (device, _server, _) = start_device_with_account()?;

        for _ in 0..forgettings {
            prop_assert_eq!(forget_this_device(&device)?, Value::Null);
        }

        prop_assert_eq!(&read_status(&device)?["account"], &Value::Null);
    }

    #[test]
    fn test_account_command_forget_this_device_property_allows_a_new_account(
        restarts_device in any::<bool>(),
    ) {
        let (mut device, _server, created) = start_device_with_account()?;
        forget_this_device(&device)?;
        if restarts_device {
            device.restart().map_err(fail)?;
        }
        let other_server = TestServer::start().map_err(fail)?;
        let request = AccountRequest::for_server(&other_server)?;

        let recreated = device.run(&request.to_command()).map_err(fail)?;

        let old_device_id = &created["device"]["id"];
        prop_assert_ne!(&recreated["device"]["id"], old_device_id);
        let status = read_status(&device)?;
        prop_assert_eq!(&status["device_id"], &recreated["device"]["id"]);
        let expected_address = Value::from(other_server.address.clone());
        prop_assert_eq!(&status["server_address"], &expected_address);
    }
}

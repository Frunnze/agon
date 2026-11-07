use proptest::prelude::*;
use serde_json::Value;

use crate::account_steps::{
    NODE_CASES, collect_names, read_field_names, read_status,
    start_device_with_account,
};
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const STATUS_FIELDS: [&str; 12] = [
    "server_address",
    "server_reachable",
    "hosted_server_address",
    "hosting_problem",
    "device_id",
    "account",
    "pending_join",
    "peer",
    "rendezvous_problem",
    "runner_settings",
    "runner_problem",
    "app_servers",
];
const OPTIONAL_TEXT_FIELDS: [&str; 6] = [
    "server_address",
    "hosted_server_address",
    "hosting_problem",
    "device_id",
    "rendezvous_problem",
    "runner_problem",
];
const OPTIONAL_OBJECT_FIELDS: [&str; 4] =
    ["account", "pending_join", "peer", "runner_settings"];
const APP_SERVER_FIELDS: [&str; 3] =
    ["servers", "this_device", "can_keep_backup"];
const KEPT_SERVER_STANDINGS: [&str; 3] = ["active", "backup", "none"];

#[derive(Clone, Copy, Debug)]
enum DeviceStage {
    Fresh,
    WithAccount,
    ServerStopped,
}

fn device_stage_strategy() -> impl Strategy<Value = DeviceStage> {
    prop_oneof![
        Just(DeviceStage::Fresh),
        Just(DeviceStage::WithAccount),
        Just(DeviceStage::ServerStopped),
    ]
}

fn reach_stage(
    stage: DeviceStage,
) -> Result<(TestDevice, Option<TestServer>), TestCaseError> {
    if let DeviceStage::Fresh = stage {
        let device = TestDevice::start().map_err(fail)?;
        return Ok((device, None));
    }
    let (device, server, _) = start_device_with_account()?;
    if let DeviceStage::ServerStopped = stage {
        server.stop().map_err(fail)?;
    }
    Ok((device, Some(server)))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_status_view_property_has_exactly_the_contract_fields(
        stage in device_stage_strategy(),
    ) {
        let (device, _server) = reach_stage(stage)?;

        let status = read_status(&device)?;

        let expected_fields = collect_names(&STATUS_FIELDS);
        prop_assert_eq!(read_field_names(&status), expected_fields);
        let app_servers = &status["app_servers"];
        prop_assert_eq!(
            read_field_names(app_servers),
            collect_names(&APP_SERVER_FIELDS)
        );
    }

    #[test]
    fn test_status_view_property_fields_have_the_decoded_types(
        stage in device_stage_strategy(),
    ) {
        let (device, _server) = reach_stage(stage)?;

        let status = read_status(&device)?;

        prop_assert!(status["server_reachable"].is_boolean());
        for field in OPTIONAL_TEXT_FIELDS {
            let shown = &status[field];
            prop_assert!(shown.is_null() || shown.is_string(), "{}", field);
        }
        for field in OPTIONAL_OBJECT_FIELDS {
            let shown = &status[field];
            prop_assert!(shown.is_null() || shown.is_object(), "{}", field);
        }
        let app_servers = &status["app_servers"];
        prop_assert!(app_servers["servers"].is_array());
        prop_assert!(app_servers["can_keep_backup"].is_boolean());
        let standing = app_servers["this_device"].as_str().unwrap_or_default();
        prop_assert!(KEPT_SERVER_STANDINGS.contains(&standing), "{standing}");
    }

    #[test]
    fn test_status_view_property_an_account_comes_with_its_device(
        stage in device_stage_strategy(),
    ) {
        let (device, server) = reach_stage(stage)?;

        let status = read_status(&device)?;

        let has_account = !status["account"].is_null();
        prop_assert_eq!(has_account, server.is_some());
        if has_account {
            let account_device_id = &status["account"]["device"]["id"];
            prop_assert_eq!(&status["device_id"], account_device_id);
            prop_assert!(status["server_address"].is_string());
        }
        if status["server_reachable"] == Value::Bool(true) {
            prop_assert!(has_account);
        }
    }
}

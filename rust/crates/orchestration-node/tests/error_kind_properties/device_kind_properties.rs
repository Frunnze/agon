use std::sync::OnceLock;

use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};

use crate::error_kind_samples::{
    ERROR_FIELD, NO_ACCOUNT_COMMANDS, SUCCESS_FIELD, build_account_command,
    no_account_reply, read_kind,
};
use crate::support::test_device::{TestDevice, fail, is_defined_reply};
use crate::support::test_server::TestServer;

const DEVICE_CASES: u32 = 3;
const PARSING_CASES: u32 = 32;
const LATEST_SEQUENCE: u64 = 1_000;
const WORKSPACE_NAME: &str = "home";
const UNKNOWN_COMMAND_PATTERN: &str = "zz_[a-z_]{1,16}";

static FRESH_DEVICE: OnceLock<Result<TestDevice, String>> = OnceLock::new();

fn fresh_device() -> Result<&'static TestDevice, TestCaseError> {
    let started_device = FRESH_DEVICE.get_or_init(TestDevice::start);
    started_device.as_ref().map_err(fail)
}

fn refused_command_strategy() -> impl Strategy<Value = Value> {
    prop_oneof![
        UNKNOWN_COMMAND_PATTERN.prop_map(|name| json!({ "command": name })),
        any::<i64>().prop_map(Value::from),
        Just(json!({ "command": "list_projects" })),
        Just(json!({ "command": "poll_events", "after": "soon" })),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PARSING_CASES))]

    #[test]
    fn test_handle_command_property_no_account_refusals_name_their_kind(
        name in select(NO_ACCOUNT_COMMANDS.to_vec()),
        after in 0..LATEST_SEQUENCE,
    ) {
        let device = fresh_device()?;

        let reply = device.send(&build_account_command(name, after));

        prop_assert_eq!(reply, no_account_reply());
    }

    #[test]
    fn test_handle_command_property_other_refusals_carry_no_kind(
        command in refused_command_strategy(),
    ) {
        let device = fresh_device()?;

        let reply = device.send(&command);

        prop_assert!(reply.get(ERROR_FIELD).is_some(), "{}", reply);
        prop_assert_eq!(read_kind(&reply), None);
        prop_assert!(is_defined_reply(&reply), "{}", reply);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DEVICE_CASES))]

    #[test]
    fn test_handle_command_property_an_account_ends_the_no_account_kind(
        name in select(NO_ACCOUNT_COMMANDS.to_vec()),
        after in 0..LATEST_SEQUENCE,
    ) {
        let server = TestServer::start().map_err(fail)?;
        let device = TestDevice::start().map_err(fail)?;
        let command = build_account_command(name, after);
        let before = device.send(&command);
        device.create_account(&server, WORKSPACE_NAME).map_err(fail)?;

        let after_account = device.send(&command);

        prop_assert_eq!(before, no_account_reply());
        prop_assert!(after_account.get(SUCCESS_FIELD).is_some());
        prop_assert_eq!(read_kind(&after_account), None);
    }
}

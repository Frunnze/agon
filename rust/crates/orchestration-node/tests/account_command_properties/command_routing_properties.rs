use std::collections::BTreeMap;
use std::fs;

use proptest::prelude::*;
use serde_json::Value;

use crate::account_steps::{
    ACCOUNT_FILE_NAME, NODE_CASES, PARSING_CASES,
    account_command_name_strategy, harmless_command, read_error,
    shared_fresh_device, start_device_with_account, with_field,
};
use crate::support::command_strategies::arbitrary_json;
use crate::support::test_device::{fail, is_defined_reply, read_success};

const MOST_RANDOM_ARGUMENTS: usize = 4;
const SURPRISE_FIELD: &str = "surprise_field";
const NO_ACCOUNT: &str = "this device has no account yet";
const NOT_AN_ADDRESS: &str = "is not an http, https or peer address";
const NAME_PROBLEM: &str = "a name can only use";

type RandomArguments = BTreeMap<String, Value>;

fn random_arguments_strategy() -> impl Strategy<Value = RandomArguments> {
    proptest::collection::btree_map(
        "[a-z_]{1,12}",
        arbitrary_json(),
        0..MOST_RANDOM_ARGUMENTS,
    )
}

fn add_arguments(command: &Value, arguments: RandomArguments) -> Value {
    let mut extended = command.clone();
    for (field, field_value) in arguments {
        if field != "command" {
            extended[field] = field_value;
        }
    }
    extended
}

fn has_handler_shape(name: &str, reply: &Value) -> bool {
    let error = read_error(reply);
    let success = read_success(reply).unwrap_or(Value::Bool(false));
    match name {
        "status" => success.get("server_reachable").is_some(),
        "retry_server" => success.get("checked_at").is_some(),
        "forget_this_device" => success.is_null(),
        "poll_events" => error == NO_ACCOUNT,
        "create_account" => error.ends_with(NOT_AN_ADDRESS),
        "create_hosted_account" => error.starts_with(NAME_PROBLEM),
        _ => false,
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PARSING_CASES))]

    #[test]
    fn test_handle_account_command_property_any_arguments_get_a_defined_reply(
        name in account_command_name_strategy(),
        arguments in random_arguments_strategy(),
    ) {
        let device = shared_fresh_device()?;
        let command = add_arguments(&harmless_command(name), arguments);

        let reply = device.send(&command);

        prop_assert!(is_defined_reply(&reply), "{} gave {}", command, reply);
    }

    #[test]
    fn test_handle_account_command_property_each_variant_has_its_own_reply(
        name in account_command_name_strategy(),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&harmless_command(name));

        prop_assert!(has_handler_shape(name, &reply), "{name}: {reply}");
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_handle_account_command_property_refused_commands_stay_local(
        name in account_command_name_strategy(),
        surprise in arbitrary_json(),
    ) {
        let (device, server, _) = start_device_with_account()?;
        let account_path =
            device.data_directory.path().join(ACCOUNT_FILE_NAME);
        let account_before = fs::read(&account_path).map_err(fail)?;
        let requests_before = server.recorded_requests().len();
        let command =
            with_field(&harmless_command(name), SURPRISE_FIELD, surprise);

        let reply = device.send(&command);

        prop_assert!(read_error(&reply).contains(SURPRISE_FIELD), "{reply}");
        prop_assert_eq!(server.recorded_requests().len(), requests_before);
        let account_after = fs::read(&account_path).map_err(fail)?;
        prop_assert_eq!(account_after, account_before);
    }
}

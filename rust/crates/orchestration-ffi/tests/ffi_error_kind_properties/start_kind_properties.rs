use std::fs;

use orchestration_node::command_reply::render_node_error_reply;
use orchestration_node::node_configuration::NodeConfiguration;
use orchestration_node::node_runtime::NodeRuntime;
use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::boundary_support::{
    NODE_CASES, node_configuration, start_fresh_node, stop_the_node,
    take_the_node,
};
use crate::support::replies::{handle_bytes, is_defined_reply};
use crate::support::starting::start_with;

const ERROR_KIND_FIELD: &str = "error_kind";
const NO_ACCOUNT_MESSAGE: &str = "this device has no account yet";
const NO_ACCOUNT_KIND: &str = "no_account";
const NO_ACCOUNT_COMMANDS: [&str; 2] = ["list_workspaces", "list_devices"];
const FIELD_NAME_PATTERN: &str = "[a-z_]{1,12}";
const BLOCKING_FILE_NAME: &str = "not-a-folder";
const MOST_FIELDS: usize = 4;

fn refused_configuration_strategy() -> impl Strategy<Value = Value> {
    let field_value = prop_oneof![
        Just(Value::Null),
        any::<i64>().prop_map(Value::from),
        any::<String>().prop_map(Value::String),
    ];
    let fields = proptest::collection::btree_map(
        FIELD_NAME_PATTERN,
        field_value,
        0..MOST_FIELDS,
    );
    prop_oneof![
        fields.prop_map(|fields| json!(fields)),
        any::<String>().prop_map(Value::String),
    ]
    .prop_filter("refused", |configuration| {
        NodeConfiguration::from_json(&configuration.to_string()).is_err()
    })
}

fn render_expected_reply(
    configuration_text: &str,
) -> Result<Value, TestCaseError> {
    let Err(refusal) = NodeRuntime::start(configuration_text) else {
        return Err(TestCaseError::fail("the node started"));
    };
    serde_json::from_str(&render_node_error_reply(&refusal))
        .map_err(|error| TestCaseError::fail(error.to_string()))
}

fn blocked_configuration() -> Result<(TempDir, Value), TestCaseError> {
    let parent_directory = TempDir::new()
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    let blocking_file = parent_directory.path().join(BLOCKING_FILE_NAME);
    fs::write(&blocking_file, b"")
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    let mut configuration = node_configuration(&parent_directory);
    configuration["data_directory"] = json!(blocking_file);
    Ok((parent_directory, configuration))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_start_node_property_a_refused_configuration_matches_the_node(
        configuration in refused_configuration_strategy(),
    ) {
        let _node_turn = take_the_node();
        let expected_reply =
            render_expected_reply(&configuration.to_string())?;

        let reply = start_with(&configuration);

        prop_assert_eq!(reply, expected_reply);
    }

    #[test]
    fn test_start_node_property_an_unopenable_folder_matches_the_node(
        attempts in 1_usize..3,
    ) {
        let _node_turn = take_the_node();
        stop_the_node();
        let (_parent_directory, configuration) = blocked_configuration()?;
        let expected_reply =
            render_expected_reply(&configuration.to_string())?;

        for _ in 0..attempts {
            let reply = start_with(&configuration);

            prop_assert_eq!(&reply, &expected_reply);
            prop_assert!(is_defined_reply(&reply), "{}", reply);
            prop_assert_eq!(reply.get(ERROR_KIND_FIELD), None);
        }
    }

    #[test]
    fn test_start_node_property_a_started_node_names_the_no_account_kind(
        name in select(NO_ACCOUNT_COMMANDS.to_vec()),
    ) {
        let _node_turn = take_the_node();
        let _data_directory = start_fresh_node()?;
        let command = json!({ "command": name }).to_string();

        let reply = handle_bytes(command.as_bytes());

        let expected_reply = json!({
            "error": NO_ACCOUNT_MESSAGE,
            ERROR_KIND_FIELD: NO_ACCOUNT_KIND,
        });
        prop_assert_eq!(&reply, &expected_reply);
        prop_assert!(is_defined_reply(&reply), "{}", reply);
        stop_the_node();
    }
}

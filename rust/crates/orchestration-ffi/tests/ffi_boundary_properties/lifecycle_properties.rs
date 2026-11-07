use std::ffi::CString;

use orchestration_ffi::orchestration_start;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::boundary_support::{
    NODE_CASES, NOT_STARTED_MESSAGE, STATUS_COMMAND, node_configuration,
    read_error, start_fresh_node, stop_the_node, take_the_node,
};
use crate::support::replies::{handle_bytes, is_defined_reply, take_reply};
use crate::support::starting::start_with;

const INVALID_CONFIGURATION_TEXT: &str = "invalid configuration";
const STOPPED_REPLY: &str = r#"{"ok":null}"#;

fn any_json_value() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        any::<bool>().prop_map(Value::Bool),
        any::<i64>().prop_map(|number| json!(number)),
        any::<String>().prop_map(Value::String),
        proptest::collection::vec(any::<String>(), 0..3)
            .prop_map(|texts| json!(texts)),
    ]
}

fn any_broken_configuration() -> impl Strategy<Value = Value> {
    let field = prop_oneof![
        Just("data_directory".to_owned()),
        Just("identity_store".to_owned()),
        Just("peer_relay".to_owned()),
        Just("server_address".to_owned()),
        "[a-z_]{1,12}",
    ];
    proptest::collection::btree_map(field, any_json_value(), 0..4)
        .prop_map(|fields| json!(fields))
        .prop_filter("not a whole configuration", |configuration| {
            configuration.get("data_directory").is_none()
        })
}

fn is_running() -> bool {
    let reply = handle_bytes(STATUS_COMMAND);
    reply.get("ok").is_some()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_guard_call_property_start_replies_are_defined(
        configuration in any_broken_configuration(),
    ) {
        let _node_turn = take_the_node();

        let reply = start_with(&configuration);

        prop_assert!(is_defined_reply(&reply), "{}", reply);
        prop_assert!(read_error(&reply).is_some(), "{}", reply);
    }

    #[test]
    fn test_guard_call_property_command_replies_are_defined(
        command_name in "[a-z_]{1,24}",
        argument in any_json_value(),
    ) {
        let _node_turn = take_the_node();
        let _data_directory = start_fresh_node()?;
        let command = json!({ "command": command_name, "value": argument });

        let reply = handle_bytes(command.to_string().as_bytes());

        prop_assert!(is_defined_reply(&reply), "{}", reply);
        stop_the_node();
    }

    #[test]
    fn test_guard_call_property_stop_replies_are_defined(
        is_started in any::<bool>(),
    ) {
        let _node_turn = take_the_node();
        let _data_directory = if is_started {
            Some(start_fresh_node()?)
        } else {
            None
        };

        let reply = stop_the_node();

        prop_assert!(is_defined_reply(&reply), "{}", reply);
    }

    #[test]
    fn test_start_node_property_a_broken_configuration_keeps_the_node(
        configuration in any_broken_configuration(),
    ) {
        let _node_turn = take_the_node();
        let _data_directory = start_fresh_node()?;

        let reply = start_with(&configuration);

        prop_assert!(read_error(&reply).is_some(), "{}", reply);
        prop_assert!(is_running());
        stop_the_node();
    }

    #[test]
    fn test_start_node_property_starting_again_replaces_the_node(
        restart_count in 1_usize..3,
    ) {
        let _node_turn = take_the_node();
        let mut data_directories = vec![start_fresh_node()?];

        for _ in 0..restart_count {
            data_directories.push(start_fresh_node()?);
            prop_assert!(is_running());
        }
        stop_the_node();
        prop_assert!(!is_running());
    }

    #[test]
    fn test_start_node_property_unreadable_text_names_the_configuration(
        text in "[a-z{\\[ ,:]{0,20}",
    ) {
        let _node_turn = take_the_node();

        let configuration_text = CString::new(text)
            .map_err(|error| TestCaseError::fail(error.to_string()))?;
        let reply = take_reply(unsafe {
            orchestration_start(configuration_text.as_ptr())
        });

        let error = read_error(&reply).unwrap_or_default();
        prop_assert!(error.contains(INVALID_CONFIGURATION_TEXT), "{}", error);
    }

    #[test]
    fn test_stop_node_property_stopping_always_replies_ok(
        is_started in any::<bool>(),
    ) {
        let _node_turn = take_the_node();
        let _data_directory = if is_started {
            Some(start_fresh_node()?)
        } else {
            None
        };

        let reply = stop_the_node();

        prop_assert_eq!(reply.to_string(), STOPPED_REPLY);
    }

    #[test]
    fn test_stop_node_property_a_stopped_node_starts_again(
        cycle_count in 1_usize..3,
    ) {
        let _node_turn = take_the_node();

        for _ in 0..cycle_count {
            let _data_directory = start_fresh_node()?;
            prop_assert!(is_running());
            stop_the_node();
            prop_assert!(!is_running());
        }
    }

    #[test]
    fn test_stop_node_property_a_stopped_node_refuses_commands(
        stop_count in 1_usize..4,
    ) {
        let _node_turn = take_the_node();
        let data_directory = start_fresh_node()?;

        for _ in 0..stop_count {
            stop_the_node();
        }
        let reply = handle_bytes(STATUS_COMMAND);
        let restarted = start_with(&node_configuration(&data_directory));

        prop_assert_eq!(read_error(&reply), Some(NOT_STARTED_MESSAGE));
        prop_assert_eq!(restarted, json!({ "ok": null }));
        stop_the_node();
    }
}

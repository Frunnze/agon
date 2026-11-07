use proptest::prelude::*;
use serde_json::{Value, json};

use crate::boundary_support::{
    NODE_CASES, NOT_STARTED_MESSAGE, STATUS_COMMAND, read_error,
    start_fresh_node, stop_the_node, take_the_node,
};
use crate::support::replies::{handle_bytes, is_defined_reply};

const KNOWN_COMMAND_NAMES: [&str; 4] =
    ["status", "list_projects", "list_runs", "list_devices"];

fn any_command_name() -> impl Strategy<Value = String> {
    prop_oneof![
        proptest::sample::select(KNOWN_COMMAND_NAMES.to_vec())
            .prop_map(str::to_owned),
        "[a-z_]{1,20}",
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_handle_command_property_an_unstarted_node_answers_not_started(
        command_name in any_command_name(),
    ) {
        let _node_turn = take_the_node();
        stop_the_node();
        let command = json!({ "command": command_name }).to_string();

        let reply = handle_bytes(command.as_bytes());

        let expected = json!({ "error": NOT_STARTED_MESSAGE });
        prop_assert_eq!(reply, expected);
    }

    #[test]
    fn test_handle_command_property_a_started_node_reports_its_status(
        status_asks in 1_usize..4,
    ) {
        let _node_turn = take_the_node();
        let _data_directory = start_fresh_node()?;

        for _ in 0..status_asks {
            let reply = handle_bytes(STATUS_COMMAND);
            let reachable = &reply["ok"]["server_reachable"];
            prop_assert_eq!(reachable, &Value::Bool(false), "{}", reply);
        }
        stop_the_node();
    }

    #[test]
    fn test_handle_command_property_a_started_node_never_says_unstarted(
        command_name in any_command_name(),
        command_text in any::<String>(),
    ) {
        let _node_turn = take_the_node();
        let _data_directory = start_fresh_node()?;
        let command = json!({ "command": command_name }).to_string();

        let named_reply = handle_bytes(command.as_bytes());
        let text_without_zero = command_text.replace('\0', "");
        let text_reply = handle_bytes(text_without_zero.as_bytes());

        for reply in [named_reply, text_reply] {
            prop_assert!(is_defined_reply(&reply), "{}", reply);
            prop_assert_ne!(read_error(&reply), Some(NOT_STARTED_MESSAGE));
        }
        stop_the_node();
    }
}

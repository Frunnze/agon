use std::ffi::{CString, c_char};
use std::ptr;

use orchestration_ffi::{
    orchestration_free_string, orchestration_handle_command,
    orchestration_start, orchestration_stop,
};
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::boundary_support::{
    NODE_CASES, NOT_STARTED_MESSAGE, NULL_INPUT_MESSAGE, read_error,
    read_reply_text, start_fresh_node, stop_the_node, take_the_node,
};
use crate::support::replies::{handle_bytes, take_reply};

const LARGEST_REPEAT_COUNT: usize = 5;

fn ask_each_entry_point(command_text: &CString) -> Vec<*mut c_char> {
    vec![
        unsafe { orchestration_handle_command(command_text.as_ptr()) },
        unsafe { orchestration_start(command_text.as_ptr()) },
        unsafe { orchestration_handle_command(ptr::null()) },
        unsafe { orchestration_start(ptr::null()) },
        orchestration_stop(),
    ]
}

fn text_without_zero(text: &str) -> Result<CString, TestCaseError> {
    CString::new(text.replace('\0', ""))
        .map_err(|error| TestCaseError::fail(error.to_string()))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_orchestration_handle_command_property_null_gives_null_error(
        is_running in any::<bool>(),
    ) {
        let _node_turn = take_the_node();
        let _data_directory = if is_running {
            Some(start_fresh_node()?)
        } else {
            stop_the_node();
            None
        };

        let reply = take_reply(unsafe {
            orchestration_handle_command(ptr::null())
        });

        prop_assert_eq!(read_error(&reply), Some(NULL_INPUT_MESSAGE));
        stop_the_node();
    }

    #[test]
    fn test_orchestration_handle_command_property_unstarted_says_so(
        command in any::<String>(),
    ) {
        let _node_turn = take_the_node();
        stop_the_node();

        let reply = handle_bytes(command.replace('\0', "").as_bytes());

        prop_assert_eq!(read_error(&reply), Some(NOT_STARTED_MESSAGE));
    }

    #[test]
    fn test_orchestration_stop_property_stopping_a_stopped_node_is_ok(
        stop_count in 1..=LARGEST_REPEAT_COUNT,
    ) {
        let _node_turn = take_the_node();

        for _ in 0..stop_count {
            prop_assert_eq!(stop_the_node(), json!({ "ok": null }));
        }
    }

    #[test]
    fn test_orchestration_stop_property_commands_after_stop_say_so(
        command_name in "[a-z_]{1,20}",
    ) {
        let _node_turn = take_the_node();
        let _data_directory = start_fresh_node()?;

        let stopped = take_reply(orchestration_stop());
        let command = json!({ "command": command_name }).to_string();
        let reply = handle_bytes(command.as_bytes());

        prop_assert_eq!(stopped, json!({ "ok": null }));
        prop_assert_eq!(read_error(&reply), Some(NOT_STARTED_MESSAGE));
    }

    #[test]
    fn test_orchestration_free_string_property_null_is_ignored(
        free_count in 1..=LARGEST_REPEAT_COUNT,
    ) {
        for _ in 0..free_count {
            unsafe { orchestration_free_string(ptr::null_mut()) };
        }

        let reply = take_reply(unsafe { orchestration_start(ptr::null()) });
        prop_assert_eq!(read_error(&reply), Some(NULL_INPUT_MESSAGE));
    }

    #[test]
    fn test_orchestration_free_string_property_every_reply_is_freeable(
        command in any::<String>(),
    ) {
        let _node_turn = take_the_node();
        let command_text = text_without_zero(&command)?;

        for reply_pointer in ask_each_entry_point(&command_text) {
            let reply_text = read_reply_text(reply_pointer)?;
            let reply: Value = serde_json::from_str(&reply_text)
                .map_err(|error| TestCaseError::fail(error.to_string()))?;
            prop_assert!(reply.is_object(), "{}", reply_text);
        }
    }

    #[test]
    fn test_orchestration_free_string_property_replies_free_in_any_order(
        commands in proptest::collection::vec(any::<String>(), 1..6),
        free_order_seed in any::<prop::sample::Index>(),
    ) {
        let _node_turn = take_the_node();
        let mut reply_pointers = Vec::new();
        for command in &commands {
            let command_text = text_without_zero(command)?;
            reply_pointers.extend(ask_each_entry_point(&command_text));
        }

        let rotation = free_order_seed.index(reply_pointers.len());
        reply_pointers.rotate_left(rotation);
        reply_pointers.reverse();
        for reply_pointer in reply_pointers {
            prop_assert!(!reply_pointer.is_null());
            unsafe { orchestration_free_string(reply_pointer) };
        }

        prop_assert_eq!(stop_the_node(), json!({ "ok": null }));
    }
}

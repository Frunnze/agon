use std::ffi::{CString, c_char};
use std::ptr;

use orchestration_ffi::{orchestration_handle_command, orchestration_start};
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::boundary_support::{
    INVALID_TEXT_MESSAGE, NODE_CASES, NOT_STARTED_MESSAGE, NULL_INPUT_MESSAGE,
    STATUS_COMMAND, read_error, read_reply_text, start_fresh_node,
    stop_the_node, take_the_node,
};
use crate::support::replies::is_defined_reply;

const INVALID_UTF8_SEQUENCES: [&[u8]; 5] = [
    &[0xFF],
    &[0xC0, 0x80],
    &[0xED, 0xA0, 0x80],
    &[0xF4, 0x90, 0x80, 0x80],
    &[0xE2, 0x82],
];
const LONG_COMMAND_CHARACTERS: usize = 100_000;

type EntryPoint = unsafe extern "C" fn(*const c_char) -> *mut c_char;

const ENTRY_POINTS: [EntryPoint; 2] =
    [orchestration_start, orchestration_handle_command];

fn call_with_bytes(
    entry_point: EntryPoint,
    input_bytes: Vec<u8>,
) -> Result<Value, TestCaseError> {
    let input_text = CString::new(input_bytes)
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    let reply_pointer = unsafe { entry_point(input_text.as_ptr()) };
    let reply_text = read_reply_text(reply_pointer)?;
    serde_json::from_str(&reply_text)
        .map_err(|error| TestCaseError::fail(error.to_string()))
}

fn any_invalid_utf8() -> impl Strategy<Value = Vec<u8>> {
    let sequence = proptest::sample::select(INVALID_UTF8_SEQUENCES.to_vec());
    ("[a-z{}\":]{0,12}", sequence, "[a-z{}\":]{0,12}").prop_map(
        |(start, sequence, end)| {
            let mut input_bytes = start.into_bytes();
            input_bytes.extend_from_slice(sequence);
            input_bytes.extend(end.into_bytes());
            input_bytes
        },
    )
}

fn without_zero(text: &str) -> Vec<u8> {
    text.replace('\0', "").into_bytes()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_read_input_property_null_input_gives_the_null_message(
        entry_pick in any::<prop::sample::Index>(),
    ) {
        let entry_point = *entry_pick.get(&ENTRY_POINTS);

        let reply_pointer = unsafe { entry_point(ptr::null()) };
        let reply_text = read_reply_text(reply_pointer)?;

        let expected = json!({ "error": NULL_INPUT_MESSAGE }).to_string();
        prop_assert_eq!(reply_text, expected);
    }

    #[test]
    fn test_read_input_property_invalid_text_gives_the_text_message(
        entry_pick in any::<prop::sample::Index>(),
        input_bytes in any_invalid_utf8(),
    ) {
        let entry_point = *entry_pick.get(&ENTRY_POINTS);

        let reply = call_with_bytes(entry_point, input_bytes)?;

        prop_assert_eq!(read_error(&reply), Some(INVALID_TEXT_MESSAGE));
    }

    #[test]
    fn test_read_input_property_valid_text_is_never_called_invalid(
        entry_pick in any::<prop::sample::Index>(),
        input in any::<String>(),
    ) {
        let _node_turn = take_the_node();
        let entry_point = *entry_pick.get(&ENTRY_POINTS);

        let reply = call_with_bytes(entry_point, without_zero(&input))?;

        let error = read_error(&reply);
        prop_assert_ne!(error, Some(INVALID_TEXT_MESSAGE));
        prop_assert_ne!(error, Some(NULL_INPUT_MESSAGE));
    }

    #[test]
    fn test_into_raw_reply_property_escaped_zeros_still_encode(
        texts in vec(any::<String>(), 1..4),
    ) {
        let _node_turn = take_the_node();
        let _data_directory = start_fresh_node()?;
        let mut command = json!({ "command": "status" });
        for (index, text) in texts.iter().enumerate() {
            command[format!("field_{index}")] = json!(format!("\0{text}\0"));
        }

        let reply = call_with_bytes(
            orchestration_handle_command,
            command.to_string().into_bytes(),
        )?;

        prop_assert!(is_defined_reply(&reply), "{}", reply);
        stop_the_node();
    }

    #[test]
    fn test_into_raw_reply_property_long_commands_get_defined_replies(
        piece in "[a-zé中😀\"\\\\{}]{1,6}",
    ) {
        let _node_turn = take_the_node();
        let _data_directory = start_fresh_node()?;
        let repeat_count = LONG_COMMAND_CHARACTERS / piece.len();
        let command = json!({ "command": piece.repeat(repeat_count) });

        let reply = call_with_bytes(
            orchestration_handle_command,
            command.to_string().into_bytes(),
        )?;

        prop_assert!(is_defined_reply(&reply), "{}", reply);
        prop_assert_ne!(read_error(&reply), Some(NOT_STARTED_MESSAGE));
        stop_the_node();
    }

    #[test]
    fn test_into_raw_reply_property_replies_are_utf8_json_objects(
        command in any::<String>(),
    ) {
        let _node_turn = take_the_node();
        let _data_directory = start_fresh_node()?;

        let command_bytes = without_zero(&command);
        let status_bytes = STATUS_COMMAND.to_vec();
        let arbitrary_reply =
            call_with_bytes(orchestration_handle_command, command_bytes)?;
        let status_reply =
            call_with_bytes(orchestration_handle_command, status_bytes)?;

        let is_defined = is_defined_reply(&arbitrary_reply);
        prop_assert!(is_defined, "{}", arbitrary_reply);
        prop_assert!(status_reply.get("ok").is_some(), "{}", status_reply);
        stop_the_node();
    }
}

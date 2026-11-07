use orchestration_node::commands::command_names;
use proptest::prelude::*;
use serde_json::json;

use crate::reply_values::json_value_strategy;

pub const STATUS_COMMAND: &str = r#"{"command":"status"}"#;
const PRINTABLE_TEXT_PATTERN: &str = "\\PC{0,40}";
const ASCII_TEXT_PATTERN: &str = "[ -~]{0,20}";
const COMMAND_NAME_PATTERN: &str = "[a-z_]{1,20}";
const INVALID_UTF8_BYTES: [u8; 5] = [0x80, 0xBF, 0xC0, 0xFE, 0xFF];

pub fn invalid_utf8_line_strategy() -> impl Strategy<Value = Vec<u8>> {
    let invalid_byte = prop::sample::select(INVALID_UTF8_BYTES.to_vec());
    (ASCII_TEXT_PATTERN, invalid_byte, ASCII_TEXT_PATTERN)
        .prop_map(join_around_invalid_byte)
}

pub fn unknown_command_strategy() -> impl Strategy<Value = String> {
    COMMAND_NAME_PATTERN
        .prop_filter("unknown", |name| is_unknown_command_name(name))
        .prop_map(|name| json!({ "command": name }).to_string())
}

pub fn hostile_text_line_strategy() -> impl Strategy<Value = String> {
    prop_oneof![
        PRINTABLE_TEXT_PATTERN,
        json_value_strategy().prop_map(|line_value| line_value.to_string()),
        unknown_command_strategy(),
        Just(STATUS_COMMAND.to_owned()),
    ]
}

fn is_unknown_command_name(name: &str) -> bool {
    !command_names().contains(&name)
}

fn join_around_invalid_byte(parts: (String, u8, String)) -> Vec<u8> {
    let (text_before, invalid_byte, text_after) = parts;
    let mut line = text_before.into_bytes();
    line.push(invalid_byte);
    line.extend_from_slice(text_after.as_bytes());
    line
}

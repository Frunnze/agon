#[path = "support/replies.rs"]
mod replies;

use std::ptr;

use orchestration_ffi::{
    orchestration_free_string, orchestration_handle_command,
};
use replies::{handle_bytes, is_defined_reply, take_reply};
use serde_json::Value;

#[test]
fn a_command_before_start_gives_a_defined_error() {
    let reply = handle_bytes(br#"{"command":"status"}"#);

    assert!(is_defined_reply(&reply));
    assert!(reply["error"].is_string());
}

#[test]
fn a_null_command_gives_a_defined_error() {
    let reply =
        take_reply(unsafe { orchestration_handle_command(ptr::null()) });

    assert!(reply["error"].is_string());
}

#[test]
fn freeing_a_null_string_does_nothing() {
    unsafe { orchestration_free_string(ptr::null_mut()) };

    assert_eq!(Value::Null, Value::Null);
}

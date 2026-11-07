use std::ffi::{CStr, c_char};
use std::sync::{Mutex, MutexGuard, PoisonError};

use orchestration_ffi::{orchestration_free_string, orchestration_stop};
use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::support::replies::take_reply;
use crate::support::starting::start_with;

pub const NULL_INPUT_MESSAGE: &str = "the input pointer is null";
pub const INVALID_TEXT_MESSAGE: &str = "the input is not valid UTF-8 text";
pub const NOT_STARTED_MESSAGE: &str =
    "the node has not started, call orchestration_start first";
pub const STATUS_COMMAND: &[u8] = br#"{"command":"status"}"#;
pub const NODE_CASES: u32 = 6;

static ONE_NODE_AT_A_TIME: Mutex<()> = Mutex::new(());

pub fn take_the_node() -> MutexGuard<'static, ()> {
    ONE_NODE_AT_A_TIME
        .lock()
        .unwrap_or_else(PoisonError::into_inner)
}

pub fn node_configuration(data_directory: &TempDir) -> Value {
    json!({
        "data_directory": data_directory.path(),
        "identity_store": "file",
        "peer_relay": "disabled",
        "runner": "off",
    })
}

pub fn start_fresh_node() -> Result<TempDir, TestCaseError> {
    let data_directory = TempDir::new()
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    let reply = start_with(&node_configuration(&data_directory));
    if reply != json!({ "ok": null }) {
        return Err(TestCaseError::fail(format!("no start: {reply}")));
    }
    Ok(data_directory)
}

pub fn stop_the_node() -> Value {
    take_reply(orchestration_stop())
}

pub fn read_reply_text(
    reply_pointer: *mut c_char,
) -> Result<String, TestCaseError> {
    if reply_pointer.is_null() {
        return Err(TestCaseError::fail("the reply pointer is null"));
    }
    let reply_text = unsafe { CStr::from_ptr(reply_pointer) }
        .to_str()
        .map(str::to_owned);
    unsafe { orchestration_free_string(reply_pointer) };
    reply_text.map_err(|error| TestCaseError::fail(error.to_string()))
}

pub fn read_error(reply: &Value) -> Option<&str> {
    reply.get("error").and_then(Value::as_str)
}

mod support;

use std::ptr;
use std::sync::OnceLock;

use orchestration_ffi::orchestration_start;
use proptest::prelude::*;
use serde_json::{Value, json};
use support::replies::{handle_bytes, is_defined_reply, take_reply};
use support::starting::start_with;
use tempfile::TempDir;

const LONGEST_FUZZ_INPUT: usize = 400;
const INVALID_UTF8_BYTES: [u8; 4] = [0x7b, 0xff, 0xfe, 0x7d];

static STARTED_NODE: OnceLock<Result<TempDir, String>> = OnceLock::new();

fn start_node() -> Result<TempDir, String> {
    let data_directory = TempDir::new().map_err(|error| error.to_string())?;
    let reply = start_with(&json!({
        "data_directory": data_directory.path(),
        "identity_store": "file",
        "peer_relay": "disabled",
    }));
    if reply.get("ok").is_none() {
        return Err(format!("the node did not start: {reply}"));
    }
    Ok(data_directory)
}

fn ensure_started() -> Result<(), TestCaseError> {
    let started = STARTED_NODE.get_or_init(start_node);
    started
        .as_ref()
        .map(|_| ())
        .map_err(|message| TestCaseError::fail(message.clone()))
}

fn nonzero_bytes_strategy() -> impl Strategy<Value = Vec<u8>> {
    proptest::collection::vec(1_u8..=255, 0..LONGEST_FUZZ_INPUT)
}

#[test]
fn status_answers_after_start() {
    let Ok(()) = ensure_started() else {
        panic!("the node starts");
    };

    let reply = handle_bytes(br#"{"command":"status"}"#);

    assert_eq!(reply["ok"]["server_reachable"], Value::Bool(false));
}

#[test]
fn invalid_utf8_gives_a_defined_error() {
    let Ok(()) = ensure_started() else {
        panic!("the node starts");
    };

    let reply = handle_bytes(&INVALID_UTF8_BYTES);

    assert!(reply["error"].is_string());
}

#[test]
fn a_null_configuration_gives_a_defined_error() {
    let reply = take_reply(unsafe { orchestration_start(ptr::null()) });

    assert!(reply["error"].is_string());
}

#[test]
fn an_invalid_configuration_gives_a_defined_error() {
    let reply = start_with(&json!({ "server_address": 7 }));

    assert!(reply["error"].is_string());
}

proptest! {
    #[test]
    fn test_orchestration_handle_command_property_arbitrary_bytes_never_crash(
        command_bytes in nonzero_bytes_strategy(),
    ) {
        ensure_started()?;

        let reply = handle_bytes(&command_bytes);

        prop_assert!(is_defined_reply(&reply));
    }

    #[test]
    fn test_orchestration_start_property_arbitrary_bytes_never_crash(
        configuration_bytes in nonzero_bytes_strategy(),
    ) {
        let Ok(configuration_text) =
            std::ffi::CString::new(configuration_bytes)
        else {
            return Err(TestCaseError::fail("bytes contain no zero"));
        };

        let reply = take_reply(unsafe {
            orchestration_start(configuration_text.as_ptr())
        });

        prop_assert!(reply["error"].is_string());
    }
}

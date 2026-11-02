mod support;

use std::sync::{Mutex, MutexGuard, PoisonError};

use proptest::prelude::*;
use serde_json::{Value, json};
use support::replies::{handle_bytes, is_defined_reply};
use support::starting::start_with;
use tempfile::TempDir;

const SETTINGS_CASES: u32 = 8;
#[cfg(not(feature = "runner"))]
const RUNNER_UNAVAILABLE: &str = "this device cannot run tasks";
const STATUS_COMMAND: &[u8] = br#"{"command":"status"}"#;

static ONE_NODE_AT_A_TIME: Mutex<()> = Mutex::new(());

fn take_the_node() -> MutexGuard<'static, ()> {
    ONE_NODE_AT_A_TIME
        .lock()
        .unwrap_or_else(PoisonError::into_inner)
}

fn start_with_runner(slot_capacity: u32) -> Result<Value, TestCaseError> {
    let data_directory = TempDir::new()
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    Ok(start_with(&json!({
        "data_directory": data_directory.path(),
        "identity_store": "file",
        "peer_relay": "disabled",
        "runner": {
            "labels": ["mac"],
            "slot_capacity": slot_capacity,
            "sandbox": { "kind": "local_process" },
        },
    })))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SETTINGS_CASES))]

    #[cfg(not(feature = "runner"))]
    #[test]
    fn test_orchestration_start_property_runner_sections_are_refused(
        slot_capacity in 1_u32..8,
    ) {
        let _node_turn = take_the_node();

        let reply = start_with_runner(slot_capacity)?;

        prop_assert_eq!(reply, json!({ "error": RUNNER_UNAVAILABLE }));
        let status = handle_bytes(STATUS_COMMAND);
        prop_assert!(is_defined_reply(&status));
    }

    #[cfg(feature = "runner")]
    #[test]
    fn test_orchestration_start_property_runner_sections_start(
        slot_capacity in 1_u32..8,
    ) {
        let _node_turn = take_the_node();

        let reply = start_with_runner(slot_capacity)?;

        prop_assert_eq!(reply, json!({ "ok": null }));
        let status = handle_bytes(STATUS_COMMAND);
        prop_assert!(is_defined_reply(&status));
        prop_assert!(status["ok"].is_object(), "{}", status);
    }
}

mod support;

use std::sync::{Mutex, MutexGuard, PoisonError};

use orchestration_ffi::orchestration_stop;
use proptest::prelude::*;
use serde_json::{Value, json};
use support::replies::{handle_bytes, is_defined_reply, take_reply};
use support::starting::start_with;
use tempfile::TempDir;

const STOP_CASES: u32 = 4;

static ONE_NODE_AT_A_TIME: Mutex<()> = Mutex::new(());

fn take_the_node() -> MutexGuard<'static, ()> {
    ONE_NODE_AT_A_TIME
        .lock()
        .unwrap_or_else(PoisonError::into_inner)
}

fn start_node(data_directory: &TempDir) -> Value {
    start_with(&json!({
        "data_directory": data_directory.path(),
        "identity_store": "file",
        "peer_relay": "disabled",
    }))
}

#[test]
fn a_command_after_stop_gives_a_defined_error() {
    let _node_turn = take_the_node();
    let Ok(data_directory) = TempDir::new() else {
        panic!("the data directory is created");
    };
    let started = start_node(&data_directory);

    let stopped = take_reply(orchestration_stop());
    let reply = handle_bytes(br#"{"command":"status"}"#);

    assert_eq!(started, json!({ "ok": null }));
    assert_eq!(stopped, json!({ "ok": null }));
    assert!(is_defined_reply(&reply));
    assert!(reply["error"].is_string(), "{reply}");
}

#[test]
fn starting_with_runner_settings_without_slots_gives_a_defined_error() {
    let Ok(data_directory) = TempDir::new() else {
        panic!("the data directory is created");
    };

    let reply = start_with(&json!({
        "data_directory": data_directory.path(),
        "identity_store": "file",
        "peer_relay": "disabled",
        "runner": {
            "labels": [],
            "slot_capacity": 0,
            "sandbox": { "kind": "local_process" },
        },
    }));

    assert!(reply["error"].is_string(), "{reply}");
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STOP_CASES))]

    #[test]
    fn test_orchestration_stop_property_stopping_twice_is_defined(
        extra_stops in 1_usize..3,
    ) {
        let _node_turn = take_the_node();
        let data_directory = TempDir::new()
            .map_err(|error| TestCaseError::fail(error.to_string()))?;
        start_node(&data_directory);

        for _ in 0..extra_stops {
            let stopped = take_reply(orchestration_stop());
            prop_assert_eq!(stopped, json!({ "ok": null }));
        }
    }
}

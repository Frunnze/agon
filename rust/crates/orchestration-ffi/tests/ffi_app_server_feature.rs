mod support;

use std::sync::{Mutex, MutexGuard, PoisonError};

use proptest::prelude::*;
use serde_json::{Value, json};
use support::replies::{handle_bytes, is_defined_reply};
use support::starting::start_with;
use tempfile::TempDir;

const HOSTING_CASES: u32 = 8;
const HOSTING_UNAVAILABLE: &str = "this device cannot host the app server";
const STATUS_COMMAND: &[u8] = br#"{"command":"status"}"#;

static ONE_NODE_AT_A_TIME: Mutex<()> = Mutex::new(());

fn take_the_node() -> MutexGuard<'static, ()> {
    ONE_NODE_AT_A_TIME
        .lock()
        .unwrap_or_else(PoisonError::into_inner)
}

fn start_node() -> Result<(TempDir, Value), TestCaseError> {
    let data_directory = TempDir::new()
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    let reply = start_with(&json!({
        "data_directory": data_directory.path(),
        "identity_store": "file",
        "peer_relay": "disabled",
        "runner": "off",
    }));
    Ok((data_directory, reply))
}

fn ask_to_host(workspace_name: &str) -> Value {
    let command = json!({
        "command": "create_hosted_account",
        "workspace_name": workspace_name,
        "device_name": "main-mac",
        "role": "client",
    });
    handle_bytes(command.to_string().as_bytes())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOSTING_CASES))]

    #[cfg(not(feature = "app-server"))]
    #[test]
    fn test_create_hosted_account_property_phones_refuse_to_host(
        workspace_name in "[a-z]{1,12}",
    ) {
        let _node_turn = take_the_node();
        let (_data_directory, started) = start_node()?;

        let reply = ask_to_host(&workspace_name);
        let status = handle_bytes(STATUS_COMMAND);

        prop_assert_eq!(started, json!({ "ok": null }));
        prop_assert_eq!(reply, json!({ "error": HOSTING_UNAVAILABLE }));
        prop_assert!(is_defined_reply(&status));
    }

    #[cfg(feature = "app-server")]
    #[test]
    fn test_create_hosted_account_property_bad_names_fail_before_hosting(
        workspace_name in "[A-Z ]{1,12}",
    ) {
        let _node_turn = take_the_node();
        let (_data_directory, started) = start_node()?;

        let reply = ask_to_host(&workspace_name);
        let status = handle_bytes(STATUS_COMMAND);

        prop_assert_eq!(started, json!({ "ok": null }));
        prop_assert!(is_defined_reply(&reply));
        prop_assert!(reply["error"].is_string(), "{}", reply);
        prop_assert_ne!(&reply["error"], &json!(HOSTING_UNAVAILABLE));
        prop_assert_eq!(&status["ok"]["hosted_server_address"], &Value::Null);
    }
}

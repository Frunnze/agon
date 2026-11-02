#![cfg(feature = "app-server")]

mod support;

use std::net::TcpListener;

use proptest::prelude::*;
use serde_json::{Value, json};
use support::replies::{handle_bytes, is_defined_reply};
use support::starting::start_with;
use tempfile::TempDir;

const RESTART_CASES: u32 = 3;
const STATUS_COMMAND: &[u8] = br#"{"command":"status"}"#;

fn find_free_port() -> Result<u16, TestCaseError> {
    let listener = TcpListener::bind("127.0.0.1:0")
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    let address = listener
        .local_addr()
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    Ok(address.port())
}

fn hosting_configuration(data_directory: &TempDir, port: u16) -> Value {
    json!({
        "data_directory": data_directory.path(),
        "identity_store": "file",
        "peer_relay": "disabled",
        "runner": "off",
        "app_server_port": port,
    })
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
    #![proptest_config(ProptestConfig::with_cases(RESTART_CASES))]

    #[test]
    fn test_orchestration_start_property_restarting_a_hosting_node_succeeds(
        workspace_name in "[a-z]{3,12}",
        restarts in 1_usize..3,
    ) {
        let data_directory = TempDir::new()
            .map_err(|error| TestCaseError::fail(error.to_string()))?;
        let configuration =
            hosting_configuration(&data_directory, find_free_port()?);

        let first_start = start_with(&configuration);
        prop_assert_eq!(first_start, json!({ "ok": null }));
        let hosted = ask_to_host(&workspace_name);
        prop_assert!(hosted["ok"].is_object(), "{}", hosted);

        for _ in 0..restarts {
            let restart = start_with(&configuration);
            prop_assert_eq!(restart, json!({ "ok": null }));
            let status = handle_bytes(STATUS_COMMAND);
            prop_assert!(is_defined_reply(&status));
            prop_assert!(
                status["ok"]["hosted_server_address"].is_string(),
                "{}",
                status
            );
        }
    }
}

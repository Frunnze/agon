use std::path::Path;
use std::thread;
use std::time::Duration;

use orchestration_node::node_runtime::NodeRuntime;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::test_device::TestDevice;
use crate::support::test_server::{RecordedRequest, TestServer};
use crate::support::waiting::wait_for;

const HEARTBEAT_PATH: &str = "/runners/heartbeat";
const CLAIM_PATH: &str = "/runners/claim";
const HEARTBEAT_LIMIT: Duration = Duration::from_secs(20);
const QUIET_PERIOD: Duration = Duration::from_secs(1);
const LONGER_THAN_A_CLAIM_INTERVAL: Duration = Duration::from_secs(7);
const RELATIVE_DATA_DIRECTORY: &str = "relative-runner-data";
const SLOT_CASES: u32 = 8;

fn runner_settings(slot_capacity: u32) -> Value {
    json!({
        "labels": ["mac"],
        "slot_capacity": slot_capacity,
        "sandbox": { "kind": "local_process" },
    })
}

fn is_runner_request(request: &RecordedRequest) -> bool {
    request.path == HEARTBEAT_PATH || request.path == CLAIM_PATH
}

fn count_runner_requests(server: &TestServer) -> usize {
    let requests = server.recorded_requests();
    requests
        .iter()
        .filter(|request| is_runner_request(request))
        .count()
}

fn start_runner_with_account(
    role: &str,
) -> Result<(TestServer, TestDevice), String> {
    let server = TestServer::start()?;
    let device = TestDevice::start_runner(&runner_settings(2))?;
    device.create_account_with_role(&server, "acme", role)?;
    Ok((server, device))
}

fn wait_for_first_heartbeat(server: &TestServer) -> Result<(), String> {
    wait_for(HEARTBEAT_LIMIT, "the first heartbeat", || {
        let requests = server.recorded_requests();
        let has_heartbeat = requests
            .iter()
            .any(|request| request.path == HEARTBEAT_PATH);
        Ok(has_heartbeat.then_some(()))
    })
}

#[test]
fn a_runner_node_announces_itself_once_its_account_exists() {
    let Ok((server, device)) = start_runner_with_account("client_and_runner")
    else {
        panic!("the runner node starts with an account");
    };

    let announced = wait_for_first_heartbeat(&server);
    let runners = device.run(&json!({
        "command": "list_runners",
        "workspace_id": "00000000-0000-0000-0000-000000000000",
    }));

    assert_eq!(announced, Ok(()));
    assert!(runners.is_ok(), "{runners:?}");
}

#[test]
fn a_client_only_node_never_starts_the_runner() {
    let Ok((server, device)) = start_runner_with_account("client") else {
        panic!("the client node starts with an account");
    };

    let status = device.run(&json!({ "command": "status" }));
    thread::sleep(QUIET_PERIOD);

    assert!(status.is_ok(), "{status:?}");
    assert_eq!(count_runner_requests(&server), 0);
}

#[test]
fn stopping_the_node_stops_the_runner_loop() {
    let Ok((server, device)) = start_runner_with_account("runner") else {
        panic!("the runner node starts with an account");
    };
    let Ok(()) = wait_for_first_heartbeat(&server) else {
        panic!("the runner sends a heartbeat");
    };

    drop(device);
    let requests_when_stopped = count_runner_requests(&server);
    thread::sleep(LONGER_THAN_A_CLAIM_INTERVAL);

    assert_eq!(count_runner_requests(&server), requests_when_stopped);
}

#[test]
fn runner_settings_with_unknown_fields_stop_the_start() {
    let mut settings = runner_settings(1);
    settings["surprise"] = json!(true);

    let started = TestDevice::start_runner(&settings);

    assert!(started.is_err());
}

#[test]
fn runner_settings_with_a_relative_data_directory_stop_the_start() {
    let configuration = json!({
        "data_directory": RELATIVE_DATA_DIRECTORY,
        "identity_store": "file",
        "runner": runner_settings(1),
    });

    let started = NodeRuntime::start(&configuration.to_string());

    assert!(started.is_err());
    assert!(!Path::new(RELATIVE_DATA_DIRECTORY).exists());
}

#[test]
fn a_clone_template_without_the_address_stops_the_start() {
    let mut settings = runner_settings(1);
    settings["clone_url_template"] = json!("https://example.com/app.git");

    let started = TestDevice::start_runner(&settings);

    let Err(message) = started else {
        panic!("the start is refused");
    };
    assert!(message.contains("clone template"), "{message}");
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SLOT_CASES))]

    #[test]
    fn test_start_property_clone_templates_with_one_address_are_accepted(
        prefix in "[a-z]{1,6}://[a-z0-9./-]{0,20}",
        suffix in "(\\.git)?",
    ) {
        let mut settings = runner_settings(1);
        settings["clone_url_template"] =
            json!(format!("{prefix}{{address}}{suffix}"));

        let started = TestDevice::start_runner(&settings);

        prop_assert!(started.is_ok(), "{:?}", started.err());
    }

    #[test]
    fn test_start_property_the_runner_needs_at_least_one_slot(
        slot_capacity in 0_u32..4,
    ) {
        let settings = runner_settings(slot_capacity);

        let started = TestDevice::start_runner(&settings);

        prop_assert_eq!(started.is_ok(), slot_capacity > 0);
        if let Err(message) = started {
            prop_assert!(message.contains("slot"), "{}", message);
        }
    }
}

#[test]
fn a_runner_without_settings_reports_detected_settings() {
    let Ok(server) = TestServer::start() else {
        panic!("the server starts");
    };
    let Ok(device) = TestDevice::start_detecting_runner() else {
        panic!("the device starts");
    };
    let Ok(_) = device.create_account_with_role(&server, "acme", "runner")
    else {
        panic!("the account is created");
    };

    let outcome =
        wait_for(HEARTBEAT_LIMIT, "a heartbeat or a problem", || {
            let status = device.run(&json!({ "command": "status" }))?;
            let has_heartbeat = server
                .recorded_requests()
                .iter()
                .any(|request| request.path == HEARTBEAT_PATH);
            let has_problem = status["runner_problem"].is_string();
            Ok((has_heartbeat || has_problem).then_some(status))
        });

    let Ok(status) = outcome else {
        panic!("the detected runner reports: {outcome:?}");
    };
    let settings = &status["runner_settings"];
    let slots = settings["slot_capacity"].as_u64();
    assert!(slots.is_some_and(|slots| slots >= 1), "{status}");
    let problem = status["runner_problem"].as_str().unwrap_or_default();
    let uses_container = settings["sandbox"]["kind"] == "container";
    assert!(problem.is_empty() || uses_container, "{status}");
    if problem.is_empty() {
        let heartbeat = server
            .recorded_requests()
            .into_iter()
            .find(|request| request.path == HEARTBEAT_PATH)
            .and_then(|request| {
                serde_json::from_slice::<Value>(&request.body).ok()
            });
        let labels = heartbeat.map(|heartbeat| heartbeat["labels"].clone());
        assert_eq!(labels.as_ref(), Some(&settings["labels"]));
    }
}

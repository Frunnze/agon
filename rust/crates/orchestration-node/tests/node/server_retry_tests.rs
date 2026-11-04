use std::time::Duration;

use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;
use crate::support::waiting::wait_for;

const AVAILABILITY_CASES: u32 = 3;
const MOST_SWITCHES: usize = 4;
const REACHABILITY_LIMIT: Duration = Duration::from_secs(20);
const DEVICE_NAME: &str = "air-laptop";

fn retry_server(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "retry_server" }))
}

fn wait_for_reachability(
    device: &TestDevice,
    expected_reachable: bool,
) -> Result<Value, String> {
    let description =
        format!("the server to be reachable: {expected_reachable}");
    wait_for(REACHABILITY_LIMIT, &description, || {
        let health = retry_server(device)?;
        let matches = health["reachable"] == expected_reachable;
        Ok(matches.then_some(health))
    })
}

#[derive(Clone, Copy, Debug)]
enum ServerSwitch {
    Stop,
    Start,
}

fn any_server_switch() -> impl Strategy<Value = ServerSwitch> {
    prop_oneof![Just(ServerSwitch::Stop), Just(ServerSwitch::Start)]
}

fn apply_switch(
    server: &TestServer,
    switch: ServerSwitch,
) -> Result<(), String> {
    match switch {
        ServerSwitch::Stop if server.is_running() => server.stop(),
        ServerSwitch::Start if !server.is_running() => server.start_again(),
        _ => Ok(()),
    }
}

fn leaves_server_running(switch: ServerSwitch) -> bool {
    matches!(switch, ServerSwitch::Start)
}

#[test]
fn test_retry_server_property_reachability_follows_the_server() {
    let Ok(server) = TestServer::start() else {
        panic!("the server starts");
    };
    let Ok(device) = TestDevice::start() else {
        panic!("the device starts");
    };
    let created = device.create_account(&server, "acme");
    assert!(created.is_ok(), "{created:?}");
    let mut runner = TestRunner::new(Config::with_cases(AVAILABILITY_CASES));
    let switch_sequences = vec(any_server_switch(), 1..MOST_SWITCHES);

    let outcome = runner.run(&switch_sequences, |switches| {
        let mut expected_reachable = true;
        for switch in &switches {
            apply_switch(&server, *switch).map_err(fail)?;
            expected_reachable = leaves_server_running(*switch);
            let health = wait_for_reachability(&device, expected_reachable)
                .map_err(fail)?;
            prop_assert_eq!(health["problem"].is_null(), expected_reachable);
        }

        let status = device.run(&json!({ "command": "status" }));

        let status = status.map_err(fail)?;
        prop_assert_eq!(
            &status["server_reachable"],
            &json!(expected_reachable)
        );
        prop_assert_eq!(&status["account"]["device"]["name"], DEVICE_NAME);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn retry_server_sees_a_stopped_server_come_back() {
    let Ok(server) = TestServer::start() else {
        panic!("the server starts");
    };
    let Ok(device) = TestDevice::start() else {
        panic!("the device starts");
    };
    let created = device.create_account(&server, "acme");
    assert!(created.is_ok(), "{created:?}");

    let stopped = server.stop();
    let while_stopped = wait_for_reachability(&device, false);
    let restarted = server.start_again();
    let after_restart = wait_for_reachability(&device, true);
    let status = device.run(&json!({ "command": "status" }));

    assert_eq!(stopped, Ok(()));
    assert_eq!(restarted, Ok(()));
    let Ok(while_stopped) = while_stopped else {
        panic!("the stopped server is unreachable: {while_stopped:?}");
    };
    assert!(while_stopped["problem"].is_string(), "{while_stopped}");
    let Ok(after_restart) = after_restart else {
        panic!("the server is reachable again: {after_restart:?}");
    };
    assert_eq!(after_restart["problem"], Value::Null);
    let Ok(status) = status else {
        panic!("the status answers: {status:?}");
    };
    assert_eq!(status["server_reachable"], json!(true));
    assert_eq!(status["account"]["device"]["name"], DEVICE_NAME);
    assert_eq!(status["account"]["device"]["kind"], "computer");
}

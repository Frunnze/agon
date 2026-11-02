use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{PreparedWorkspace, prepare_workspace};
use crate::support::pairing_steps::{
    JOINING_NAME, StartedJoin, join_with_code, start_join, start_pairing,
};
use crate::support::test_device::{TestDevice, fail, read_text};

const CANCEL_CASES: u32 = 4;
const UNKNOWN_SESSION_ERROR: &str =
    "the app server answered 404: the pairing session was not found";
const CODE_FIELDS: [&str; 2] = ["/code", "/display_code"];

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn started_join_or_panic() -> StartedJoin {
    match start_join() {
        Ok(started) => started,
        Err(message) => panic!("the join starts: {message}"),
    }
}

fn cancel_pairing(
    prepared: &PreparedWorkspace,
    code: &str,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "cancel_pairing",
        "code": code,
    }))
}

fn read_pairing_request(
    prepared: &PreparedWorkspace,
    code: &Value,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "pairing_request",
        "code": code,
    }))
}

fn read_join_state(joining_device: &TestDevice) -> Result<Value, String> {
    let status = joining_device.run(&json!({ "command": "join_status" }))?;
    Ok(status["state"].clone())
}

fn list_device_names(
    prepared: &PreparedWorkspace,
) -> Result<Vec<Value>, String> {
    let devices =
        prepared.device.run(&json!({ "command": "list_devices" }))?;
    let device_views = devices.as_array().cloned().unwrap_or_default();
    let mut names = Vec::new();
    for device_view in device_views {
        names.push(device_view["device"]["name"].clone());
    }
    Ok(names)
}

#[test]
fn test_cancel_pairing_property_a_cancelled_code_can_no_longer_be_used() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(CANCEL_CASES));

    let outcome = runner.run(&(0..CODE_FIELDS.len()), |field_position| {
        let session = start_pairing(&prepared).map_err(fail)?;
        let typed_code =
            read_text(&session, CODE_FIELDS[field_position]).map_err(fail)?;
        let joining_device = TestDevice::start().map_err(fail)?;

        let cancelled = cancel_pairing(&prepared, &typed_code);
        let shown = read_pairing_request(&prepared, &session["code"]);
        let joined = join_with_code(&prepared, &joining_device, &typed_code);

        prop_assert_eq!(cancelled, Ok(Value::Null));
        prop_assert_eq!(shown, Err(UNKNOWN_SESSION_ERROR.to_owned()));
        prop_assert_eq!(joined, Err(UNKNOWN_SESSION_ERROR.to_owned()));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn cancel_pairing_tells_the_waiting_device_it_was_rejected() {
    let started = started_join_or_panic();
    let code = read_text(&started.session, "/code").unwrap_or_default();

    let cancelled = cancel_pairing(&started.prepared, &code);
    let join_state = read_join_state(&started.joining_device);
    let device_names = list_device_names(&started.prepared);

    assert_eq!(cancelled, Ok(Value::Null));
    assert_eq!(join_state, Ok(json!("rejected")));
    let Ok(device_names) = device_names else {
        panic!("the devices are listed: {device_names:?}");
    };
    assert!(!device_names.contains(&json!(JOINING_NAME)));
}

#[test]
fn cancel_pairing_twice_gives_a_defined_error() {
    let prepared = prepared_or_panic();
    let Ok(session) = start_pairing(&prepared) else {
        panic!("pairing starts");
    };
    let code = read_text(&session, "/code").unwrap_or_default();

    let first = cancel_pairing(&prepared, &code);
    let second = cancel_pairing(&prepared, &code);

    assert_eq!(first, Ok(Value::Null));
    assert_eq!(second, Err(UNKNOWN_SESSION_ERROR.to_owned()));
}

#[test]
fn reject_pairing_tells_the_waiting_device_and_ends_the_session() {
    let started = started_join_or_panic();

    let rejected = started.prepared.device.run(&json!({
        "command": "reject_pairing",
        "code": started.session["code"],
    }));
    let join_state = read_join_state(&started.joining_device);
    let shown =
        read_pairing_request(&started.prepared, &started.session["code"]);
    let device_names = list_device_names(&started.prepared);

    assert_eq!(rejected, Ok(Value::Null));
    assert_eq!(join_state, Ok(json!("rejected")));
    assert_eq!(shown, Err(UNKNOWN_SESSION_ERROR.to_owned()));
    let Ok(device_names) = device_names else {
        panic!("the devices are listed: {device_names:?}");
    };
    assert_eq!(device_names.len(), 1);
    assert!(!device_names.contains(&json!(JOINING_NAME)));
}

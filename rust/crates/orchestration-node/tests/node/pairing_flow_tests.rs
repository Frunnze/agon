use serde_json::json;

use crate::support::command_builders::{
    create_task_command, prepare_workspace,
};
use crate::support::pairing_steps::{
    JOINING_NAME, StartedJoin, join_with_code, read_both_words, start_join,
    start_pairing,
};
use crate::support::test_device::TestDevice;

const SECRET_DETAILS: &str = "secret details only devices can read";

#[test]
fn start_pairing_shows_the_code_with_a_dash() {
    let Ok(prepared) = prepare_workspace() else {
        panic!("the workspace is prepared");
    };

    let session = start_pairing(&prepared);

    let Ok(session) = session else {
        panic!("pairing starts: {session:?}");
    };
    let code = session["code"].as_str().unwrap_or_default();
    let display_code = session["display_code"].as_str().unwrap_or_default();
    assert_eq!(code.len(), 6);
    assert_eq!(display_code, format!("{}-{}", &code[..3], &code[3..]));
}

#[test]
fn both_devices_compute_the_same_fingerprint_words() {
    let started = start_join();
    let Ok(StartedJoin {
        prepared,
        joining_device,
        session,
        ..
    }) = started
    else {
        panic!("the join starts: {started:?}");
    };

    let shown = read_both_words(&prepared.device, &joining_device, &session);
    let request = prepared.device.run(&json!({
        "command": "pairing_request",
        "code": session["code"],
    }));

    let Ok(shown) = shown else {
        panic!("both devices show words: {shown:?}");
    };
    assert_eq!(shown.joiner_words.as_array().map(Vec::len), Some(4));
    assert_eq!(shown.approver_words, shown.joiner_words);
    let Ok(request) = request else {
        panic!("the request is read again: {request:?}");
    };
    assert_eq!(request["joining"]["name"], JOINING_NAME);
    assert_eq!(request["joining"]["fingerprint_words"], shown.joiner_words);
}

#[test]
fn a_waiting_join_shows_no_words_before_the_trusted_device_reveals() {
    let Ok(StartedJoin {
        joining_device,
        joined,
        ..
    }) = start_join()
    else {
        panic!("the join starts");
    };

    let status = joining_device.run(&json!({ "command": "join_status" }));

    let Ok(status) = status else {
        panic!("the join status answers: {status:?}");
    };
    assert_eq!(status["state"], json!("waiting"));
    assert_eq!(status["fingerprint_words"], json!([]));
    assert!(joined.get("fingerprint_words").is_none());
    assert!(joined["join_id"].is_string());
}

#[test]
fn a_paired_device_opens_content_sealed_by_the_trusted_device() {
    let Ok(StartedJoin {
        prepared,
        joining_device,
        session,
        ..
    }) = start_join()
    else {
        panic!("the join starts");
    };
    let Ok(_) = prepared.device.run(&create_task_command(
        &prepared.workspace_id,
        &prepared.project_id,
        SECRET_DETAILS,
    )) else {
        panic!("the task is created");
    };

    let approved = prepared.device.run(&json!({
        "command": "approve_pairing",
        "code": session["code"],
        "workspace_ids": [prepared.workspace_id],
    }));
    let status = joining_device.run(&json!({ "command": "join_status" }));
    let tasks = joining_device.run(&json!({
        "command": "list_tasks",
        "workspace_id": prepared.workspace_id,
    }));

    assert!(approved.is_ok(), "{approved:?}");
    let (Ok(status), Ok(tasks)) = (status, tasks) else {
        panic!("the join status and tasks answer");
    };
    assert_eq!(status["state"], "approved");
    assert_eq!(status["workspaces"][0]["name"], "acme");
    assert_eq!(tasks["tasks"][0]["task"]["details"], SECRET_DETAILS);
}

#[test]
fn a_join_with_a_malformed_code_gives_a_defined_error() {
    let Ok(prepared) = prepare_workspace() else {
        panic!("the workspace is prepared");
    };
    let Ok(joining_device) = TestDevice::start() else {
        panic!("the joining device starts");
    };

    let joined = join_with_code(&prepared, &joining_device, "not a code");

    assert!(joined.is_err());
}

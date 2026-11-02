use std::fs;
use std::time::Duration;

use serde_json::{Value, json};

use super::hosting_steps::{pick_free_port, read_status};
use super::test_device::{TestDevice, describe, read_text};
use super::waiting::wait_for;

pub const TAKEOVER_SECONDS: u64 = 3;
pub const SYNC_LIMIT: Duration = Duration::from_secs(90);
const STATE_FILE_PATH: &str = "hosted-app-server/state.json";
const CLIENT_ROLE: &str = "client";

pub fn start_backup_device() -> Result<TestDevice, String> {
    TestDevice::start_keeping(pick_free_port()?, TAKEOVER_SECONDS)
}

pub fn start_server_backup(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "start_server_backup" }))
}

pub fn pair_client_at(
    hosting: &TestDevice,
    joining: &TestDevice,
    server_address: &str,
    workspace_id: &str,
    device_name: &str,
) -> Result<(), String> {
    let session = hosting.run(&json!({ "command": "start_pairing" }))?;
    joining.run(&json!({
        "command": "join_with_code",
        "server_address": server_address,
        "code": read_text(&session, "/display_code")?,
        "device_name": device_name,
        "role": CLIENT_ROLE,
    }))?;
    hosting.run(&json!({
        "command": "pairing_request",
        "code": session["code"],
    }))?;
    joining.run(&json!({ "command": "join_status" }))?;
    hosting.run(&json!({
        "command": "approve_pairing",
        "code": session["code"],
        "workspace_ids": [workspace_id],
    }))?;
    let status = joining.run(&json!({ "command": "join_status" }))?;
    if status["state"] != "approved" {
        return Err(format!("the join ended as {status}"));
    }
    Ok(())
}

pub fn read_app_servers(device: &TestDevice) -> Result<Value, String> {
    let status = read_status(device)?;
    Ok(status["app_servers"].clone())
}

pub fn wait_until_standing(
    device: &TestDevice,
    standing: &str,
    limit: Duration,
) -> Result<Value, String> {
    let description = format!("the device to be the {standing} server");
    wait_for(limit, &description, || {
        let app_servers = read_app_servers(device)?;
        let is_reached = app_servers["this_device"] == standing;
        Ok(is_reached.then_some(app_servers))
    })
}

pub fn read_hosted_state(device: &TestDevice) -> Result<Value, String> {
    let state_path = device.data_directory.path().join(STATE_FILE_PATH);
    let state_bytes = fs::read(state_path).map_err(describe)?;
    serde_json::from_slice(&state_bytes).map_err(describe)
}

pub fn wait_until_copied(
    source: &TestDevice,
    copy: &TestDevice,
) -> Result<Value, String> {
    wait_for(SYNC_LIMIT, "the copy to match its source", || {
        let source_state = read_hosted_state(source)?;
        let Ok(copied_state) = read_hosted_state(copy) else {
            return Ok(None);
        };
        let is_same = source_state["revision"] == copied_state["revision"]
            && source_state["audit_log"] == copied_state["audit_log"];
        Ok(is_same.then_some(copied_state))
    })
}

pub fn list_task_titles(state: &Value) -> Vec<String> {
    let mut titles = Vec::new();
    let Some(tasks) = state["tasks"].as_object() else {
        return titles;
    };
    for task in tasks.values() {
        if let Some(title) = task["title"].as_str() {
            titles.push(title.to_owned());
        }
    }
    titles
}

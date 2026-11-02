use serde_json::{Value, json};

use super::command_builders::{PreparedWorkspace, prepare_workspace};
use super::test_device::{TestDevice, read_text};

pub const JOINING_NAME: &str = "mac-mini";
const JOINING_ROLE: &str = "client";

#[derive(Debug)]
pub struct ShownWords {
    pub approver_words: Value,
    pub joiner_words: Value,
}

#[derive(Debug)]
pub struct StartedJoin {
    pub prepared: PreparedWorkspace,
    pub joining_device: TestDevice,
    pub session: Value,
    pub joined: Value,
}

pub fn start_pairing(prepared: &PreparedWorkspace) -> Result<Value, String> {
    prepared.device.run(&json!({ "command": "start_pairing" }))
}

pub fn join_with_code(
    prepared: &PreparedWorkspace,
    joining_device: &TestDevice,
    code: &str,
) -> Result<Value, String> {
    join_at_address(joining_device, &prepared.server.address, code)
}

pub fn join_on_local_network(
    joining_device: &TestDevice,
    code: &str,
) -> Result<Value, String> {
    joining_device.run(&json!({
        "command": "join_with_code",
        "code": code,
        "device_name": JOINING_NAME,
        "role": JOINING_ROLE,
    }))
}

pub fn join_at_address(
    joining_device: &TestDevice,
    server_address: &str,
    code: &str,
) -> Result<Value, String> {
    joining_device.run(&json!({
        "command": "join_with_code",
        "server_address": server_address,
        "code": code,
        "device_name": JOINING_NAME,
        "role": JOINING_ROLE,
    }))
}

pub fn approve_into_first_workspace(
    approving_device: &TestDevice,
    session: &Value,
    account: &Value,
) -> Result<Value, String> {
    approving_device.run(&json!({
        "command": "approve_pairing",
        "code": session["code"],
        "workspace_ids": [account["workspaces"][0]["id"]],
    }))
}

pub fn read_both_words(
    approving_device: &TestDevice,
    joining_device: &TestDevice,
    session: &Value,
) -> Result<ShownWords, String> {
    let request = approving_device.run(&json!({
        "command": "pairing_request",
        "code": session["code"],
    }))?;
    let status = joining_device.run(&json!({ "command": "join_status" }))?;
    Ok(ShownWords {
        approver_words: request["joining"]["fingerprint_words"].clone(),
        joiner_words: status["fingerprint_words"].clone(),
    })
}

pub fn start_join() -> Result<StartedJoin, String> {
    let prepared = prepare_workspace()?;
    let joining_device = TestDevice::start()?;
    let session = start_pairing(&prepared)?;
    let display_code = read_text(&session, "/display_code")?;
    let joined = join_with_code(&prepared, &joining_device, &display_code)?;
    Ok(StartedJoin {
        prepared,
        joining_device,
        session,
        joined,
    })
}

pub fn pair_into_workspace(
    prepared: &PreparedWorkspace,
    joining_device: &TestDevice,
) -> Result<String, String> {
    let session = start_pairing(prepared)?;
    let display_code = read_text(&session, "/display_code")?;
    join_with_code(prepared, joining_device, &display_code)?;
    prepared.device.run(&json!({
        "command": "approve_pairing",
        "code": session["code"],
        "workspace_ids": [prepared.workspace_id],
    }))?;
    let joined = joining_device.run(&json!({ "command": "join_status" }))?;
    read_text(&joined, "/device/id")
}

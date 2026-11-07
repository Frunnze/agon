use std::path::{Path, PathBuf};

use orchestration_node::node_runtime::NodeRuntime;
use serde_json::{Value, json};

use crate::support::hosting_steps::{
    HOSTED_WORKSPACE_NAME, HOSTING_DEVICE_NAME,
};
use crate::support::test_device::{
    RELAY_DISABLED, describe, read_success, read_text,
};

const RUNNER_OFF: &str = "off";
const HOSTING_ROLE: &str = "client";
const HOSTED_SERVER_DIRECTORY_NAME: &str = "hosted-app-server";
const HOSTED_SERVER_RECORD_NAME: &str = "hosted-app-server.json";

pub fn start_runtime(
    data_directory: &Path,
    app_server_port: u16,
) -> Result<NodeRuntime, String> {
    let configuration = json!({
        "data_directory": data_directory,
        "identity_store": "file",
        "peer_relay": RELAY_DISABLED,
        "runner": RUNNER_OFF,
        "app_server_port": app_server_port,
    });
    NodeRuntime::start(&configuration.to_string()).map_err(describe)
}

pub fn run_on(
    runtime: &NodeRuntime,
    command: &Value,
) -> Result<Value, String> {
    let reply_text = runtime.handle_command(&command.to_string());
    let reply: Value = serde_json::from_str(&reply_text).map_err(describe)?;
    read_success(&reply)
}

pub fn host_on(runtime: &NodeRuntime) -> Result<Value, String> {
    run_on(
        runtime,
        &json!({
            "command": "create_hosted_account",
            "workspace_name": HOSTED_WORKSPACE_NAME,
            "device_name": HOSTING_DEVICE_NAME,
            "role": HOSTING_ROLE,
        }),
    )
}

pub fn read_hosted_address_on(
    runtime: &NodeRuntime,
) -> Result<String, String> {
    let status = run_on(runtime, &json!({ "command": "status" }))?;
    read_text(&status, "/hosted_server_address")
}

pub fn hosted_directory_in(data_directory: &Path) -> PathBuf {
    data_directory.join(HOSTED_SERVER_DIRECTORY_NAME)
}

pub fn hosted_record_in(data_directory: &Path) -> PathBuf {
    data_directory.join(HOSTED_SERVER_RECORD_NAME)
}

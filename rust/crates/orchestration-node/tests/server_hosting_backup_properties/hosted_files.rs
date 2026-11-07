use std::fs;
use std::net::{Ipv4Addr, TcpListener};
use std::path::PathBuf;

use serde_json::{Value, json};

use crate::support::hosting_steps::hosted_server_files;
use crate::support::test_device::{TestDevice, describe};

const ANY_FREE_PORT: u16 = 0;
const APP_SERVER_RECORD_NAME: &str = "app-server.json";
const SETUP_CODE_FILE_NAME: &str = "setup-code";
const MISSING_PORT: &str = "the hosted server record names no port";
const NOT_REMOVED_PREFIX: &str =
    "the app server on this device could not be removed: ";

pub fn is_port_free(port: u16) -> bool {
    TcpListener::bind((Ipv4Addr::LOCALHOST, port)).is_ok()
}

pub fn pick_two_free_ports() -> Result<(u16, u16), String> {
    let first_listener =
        TcpListener::bind((Ipv4Addr::UNSPECIFIED, ANY_FREE_PORT))
            .map_err(describe)?;
    let second_listener =
        TcpListener::bind((Ipv4Addr::UNSPECIFIED, ANY_FREE_PORT))
            .map_err(describe)?;
    let first_port = first_listener.local_addr().map_err(describe)?.port();
    let second_port = second_listener.local_addr().map_err(describe)?.port();
    Ok((first_port, second_port))
}

pub fn hosted_server_directory(device: &TestDevice) -> PathBuf {
    let [server_directory, _server_record] = hosted_server_files(device);
    server_directory
}

pub fn hosted_server_record(device: &TestDevice) -> PathBuf {
    let [_server_directory, server_record] = hosted_server_files(device);
    server_record
}

pub fn list_left_server_files(device: &TestDevice) -> Vec<PathBuf> {
    let mut left_files = Vec::new();
    for path in hosted_server_files(device) {
        if path.exists() {
            left_files.push(path);
        }
    }
    left_files
}

pub fn write_hosted_record(
    device: &TestDevice,
    port: u16,
) -> Result<(), String> {
    let record = json!({ "port": port });
    fs::write(hosted_server_record(device), record.to_string())
        .map_err(describe)
}

pub fn read_record_port(device: &TestDevice) -> Result<u16, String> {
    let record_bytes =
        fs::read(hosted_server_record(device)).map_err(describe)?;
    let record: Value =
        serde_json::from_slice(&record_bytes).map_err(describe)?;
    let port = record["port"].as_u64().ok_or(MISSING_PORT)?;
    u16::try_from(port).map_err(describe)
}

pub fn read_app_server_record(device: &TestDevice) -> Result<Value, String> {
    let record_path =
        device.data_directory.path().join(APP_SERVER_RECORD_NAME);
    let record_bytes = fs::read(record_path).map_err(describe)?;
    serde_json::from_slice(&record_bytes).map_err(describe)
}

pub fn read_hosted_setup_code(device: &TestDevice) -> Result<String, String> {
    let code_path = hosted_server_directory(device).join(SETUP_CODE_FILE_NAME);
    let setup_code = fs::read_to_string(code_path).map_err(describe)?;
    Ok(setup_code.trim().to_owned())
}

pub fn loopback_address(port: u16) -> String {
    format!("http://127.0.0.1:{port}")
}

pub fn is_named_refusal(problem: &str) -> bool {
    let detail = problem.strip_prefix(NOT_REMOVED_PREFIX);
    detail.is_some_and(|detail| !detail.trim().is_empty())
}

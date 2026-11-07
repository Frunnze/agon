use std::fs;

use serde_json::{Value, json};

use crate::hosted_files::hosted_server_directory;
use crate::support::hosting_steps::{
    HostingDevice, pick_free_port, read_hosted_address, start_hosting_device,
};
use crate::support::server_backups::{pair_client_at, read_app_servers};
use crate::support::test_device::{TestDevice, describe, read_text};

pub const STEADY_TAKEOVER_SECONDS: u64 = 3600;
const BACKUP_DEVICE_NAME: &str = "studio-mac";
const STATE_FILE_NAME: &str = "state.json";
const MISSING_SERVER_LIST: &str = "the view lists no servers";

#[derive(Debug)]
pub struct BackupGroup {
    pub hosting: HostingDevice,
    pub backup: TestDevice,
    pub backup_port: u16,
    pub workspace_id: String,
}

pub fn pair_backup_device() -> Result<BackupGroup, String> {
    let hosting = start_hosting_device()?;
    let workspace_id = read_text(&hosting.account, "/workspaces/0/id")?;
    let address = read_hosted_address(&hosting.device)?;
    let backup_port = pick_free_port()?;
    let backup =
        TestDevice::start_keeping(backup_port, STEADY_TAKEOVER_SECONDS)?;
    pair_client_at(
        &hosting.device,
        &backup,
        &address,
        &workspace_id,
        BACKUP_DEVICE_NAME,
    )?;
    Ok(BackupGroup {
        hosting,
        backup,
        backup_port,
        workspace_id,
    })
}

pub fn list_server_device_ids(
    device: &TestDevice,
) -> Result<Vec<String>, String> {
    let app_servers = read_app_servers(device)?;
    let servers = app_servers["servers"]
        .as_array()
        .ok_or(MISSING_SERVER_LIST)?;
    let mut device_ids = Vec::new();
    for server in servers {
        device_ids.push(read_text(server, "/device_id")?);
    }
    Ok(device_ids)
}

pub fn read_own_device_id(device: &TestDevice) -> Result<String, String> {
    let status = device.run(&json!({ "command": "status" }))?;
    read_text(&status, "/device_id")
}

pub fn read_own_standing(device: &TestDevice) -> Result<Value, String> {
    let app_servers = read_app_servers(device)?;
    Ok(app_servers["this_device"].clone())
}

pub fn block_state_file(
    device: &TestDevice,
    blocking_file_names: &[String],
) -> Result<(), String> {
    let state_path = hosted_server_directory(device).join(STATE_FILE_NAME);
    fs::create_dir_all(&state_path).map_err(describe)?;
    for file_name in blocking_file_names {
        fs::write(state_path.join(file_name), file_name).map_err(describe)?;
    }
    Ok(())
}

use std::time::Duration;

use serde_json::json;
use tempfile::TempDir;

use crate::backup_group::{BackupGroup, PairedDevice, revoke_device};
use crate::hosting_desk::{
    hosting_configuration, keep_data_in_target, keeping_configuration,
    stop_and_keep_data,
};
use crate::logged_host::LoggedHost;
use crate::support::hosting_steps::{
    HOSTED_WORKSPACE_NAME, HOSTING_DEVICE_NAME, HostingDevice, pick_free_port,
};
use crate::support::test_device::describe;
use crate::support::waiting::wait_for;

pub const LOG_LIMIT: Duration = Duration::from_secs(60);
const HOSTING_ROLE: &str = "client";

#[derive(Debug)]
pub struct ProcessBackup {
    pub hosting: HostingDevice,
    pub host: LoggedHost,
    pub data_directory: TempDir,
    pub workspace_id: String,
    pub device_id: String,
}

#[derive(Debug)]
pub struct ProcessHosting {
    pub host: LoggedHost,
    pub port: u16,
    _data_directory: TempDir,
}

pub fn move_backup_into_a_process(
    group: BackupGroup,
    takeover_seconds: u64,
) -> Result<ProcessBackup, String> {
    let BackupGroup {
        hosting,
        backup,
        backup_port,
        workspace_id,
        ..
    } = group;
    let paired = PairedDevice {
        hosting,
        device: backup,
        port: backup_port,
        workspace_id,
    };
    move_paired_device_into_a_process(paired, takeover_seconds)
}

pub fn move_paired_device_into_a_process(
    paired: PairedDevice,
    takeover_seconds: u64,
) -> Result<ProcessBackup, String> {
    let PairedDevice {
        hosting,
        device,
        port,
        workspace_id,
    } = paired;
    let device_id = device.load_identity()?.device_id().0;
    let data_directory = stop_and_keep_data(device);
    let configuration =
        keeping_configuration(data_directory.path(), port, takeover_seconds);
    let host = LoggedHost::start(&configuration)?;
    Ok(ProcessBackup {
        hosting,
        host,
        data_directory,
        workspace_id,
        device_id,
    })
}

pub fn host_in_a_process() -> Result<ProcessHosting, String> {
    keep_data_in_target()?;
    let data_directory = TempDir::new().map_err(describe)?;
    let port = pick_free_port()?;
    let configuration = hosting_configuration(data_directory.path(), port);
    let mut host = LoggedHost::start(&configuration)?;
    host.run(&json!({
        "command": "create_hosted_account",
        "workspace_name": HOSTED_WORKSPACE_NAME,
        "device_name": HOSTING_DEVICE_NAME,
        "role": HOSTING_ROLE,
    }))?;
    Ok(ProcessHosting {
        host,
        port,
        _data_directory: data_directory,
    })
}

pub fn revoke_the_backup(backup: &ProcessBackup) -> Result<(), String> {
    revoke_device(&backup.hosting.device, &backup.device_id)
}

pub fn wait_for_logged_line(
    host: &LoggedHost,
    line_start: &str,
) -> Result<String, String> {
    let description = format!("a log line starting {line_start}");
    wait_for(LOG_LIMIT, &description, || {
        let lines = host.read_logged_lines();
        let found =
            lines.into_iter().find(|line| line.starts_with(line_start));
        Ok(found)
    })
}

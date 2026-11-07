use std::sync::OnceLock;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

use orchestration_api::server_group::ServerGroupView;
use serde_json::{Value, json};

use crate::hosting_desk::{
    host_a_server, keep_data_in_target, read_own_group,
};
use crate::support::hosting_steps::{
    HostingDevice, pick_free_port, read_hosted_address,
};
use crate::support::server_backups::{
    TAKEOVER_SECONDS, create_project, pair_client_at, read_hosted_state,
    start_server_backup, wait_until_copied, wait_until_standing,
};
use crate::support::test_device::{StoppedDevice, TestDevice, read_text};

pub const STEADY_TAKEOVER_SECONDS: u64 = 3600;
pub const READY_TAKEOVER_SECONDS: u64 = TAKEOVER_SECONDS;
pub const TAKEOVER_LIMIT: Duration = Duration::from_secs(60);
pub const RETURN_LIMIT: Duration = Duration::from_secs(120);
const BACKUP_NAME: &str = "studio-mac";
const PROJECT_PREFIX: &str = "kept-project";
const MISSING_REVISION: &str = "the saved state has no revision";

static SHARED_GROUP: OnceLock<Result<BackupGroup, String>> = OnceLock::new();
static WRITTEN_PROJECTS: AtomicUsize = AtomicUsize::new(0);

#[derive(Debug)]
pub struct BackupGroup {
    pub hosting: HostingDevice,
    pub backup: TestDevice,
    pub backup_port: u16,
    pub workspace_id: String,
    pub started: Value,
}

#[derive(Debug)]
pub struct PairedDevice {
    pub hosting: HostingDevice,
    pub device: TestDevice,
    pub port: u16,
    pub workspace_id: String,
}

pub fn pair_a_keeping_device(
    takeover_seconds: u64,
) -> Result<PairedDevice, String> {
    let hosting = host_a_server()?;
    let workspace_id = read_text(&hosting.account, "/workspaces/0/id")?;
    let address = read_hosted_address(&hosting.device)?;
    keep_data_in_target()?;
    let port = pick_free_port()?;
    let device = TestDevice::start_keeping(port, takeover_seconds)?;
    pair_client_at(
        &hosting.device,
        &device,
        &address,
        &workspace_id,
        BACKUP_NAME,
    )?;
    Ok(PairedDevice {
        hosting,
        device,
        port,
        workspace_id,
    })
}

pub fn start_backup_group(
    takeover_seconds: u64,
) -> Result<BackupGroup, String> {
    let paired = pair_a_keeping_device(takeover_seconds)?;
    let started = start_server_backup(&paired.device)?;
    Ok(BackupGroup {
        hosting: paired.hosting,
        backup: paired.device,
        backup_port: paired.port,
        workspace_id: paired.workspace_id,
        started,
    })
}

pub fn shared_backup_group() -> Result<&'static BackupGroup, String> {
    let group = SHARED_GROUP
        .get_or_init(|| start_backup_group(STEADY_TAKEOVER_SECONDS));
    group.as_ref().map_err(Clone::clone)
}

impl BackupGroup {
    pub fn read_active_group(&self) -> Result<ServerGroupView, String> {
        read_own_group(&self.hosting.device, self.hosting.port)
    }

    pub fn read_backup_group(&self) -> Result<ServerGroupView, String> {
        read_own_group(&self.backup, self.backup_port)
    }

    pub fn write_and_wait_for_copy(&self) -> Result<Value, String> {
        let number = WRITTEN_PROJECTS.fetch_add(1, Ordering::SeqCst);
        let name = format!("{PROJECT_PREFIX}-{number}");
        create_project(&self.hosting.device, &self.workspace_id, &name)?;
        wait_until_copied(&self.hosting.device, &self.backup)
    }

    pub fn revoke_the_backup(&self) -> Result<(), String> {
        let identity = self.backup.load_identity()?;
        revoke_device(&self.hosting.device, &identity.device_id().0)
    }

    pub fn restart_the_backup(self) -> Result<Self, String> {
        let backup = self.backup.stop_and_start_again()?;
        Ok(Self { backup, ..self })
    }

    pub fn stop_active_and_wait_for_takeover(
        self,
    ) -> Result<TakenOverGroup, String> {
        let Self {
            hosting,
            backup,
            backup_port,
            workspace_id,
            ..
        } = self;
        let HostingDevice { device, port, .. } = hosting;
        let stopped = device.stop();
        let took_over =
            wait_until_standing(&backup, "active", TAKEOVER_LIMIT)?;
        Ok(TakenOverGroup {
            stopped,
            backup,
            backup_port,
            active_port: port,
            workspace_id,
            took_over,
        })
    }
}

#[derive(Debug)]
pub struct TakenOverGroup {
    pub stopped: StoppedDevice,
    pub backup: TestDevice,
    pub backup_port: u16,
    pub active_port: u16,
    pub workspace_id: String,
    pub took_over: Value,
}

#[derive(Debug)]
pub struct ReturnedGroup {
    pub returned: TestDevice,
    pub returned_port: u16,
    pub active: TestDevice,
    pub active_port: u16,
    pub workspace_id: String,
}

impl TakenOverGroup {
    pub fn return_the_old_active(self) -> Result<ReturnedGroup, String> {
        let returned = self.stopped.start_again()?;
        wait_until_standing(&returned, "backup", RETURN_LIMIT)?;
        Ok(ReturnedGroup {
            returned,
            returned_port: self.active_port,
            active: self.backup,
            active_port: self.backup_port,
            workspace_id: self.workspace_id,
        })
    }
}

pub fn start_and_take_over() -> Result<TakenOverGroup, String> {
    let group = start_backup_group(READY_TAKEOVER_SECONDS)?;
    group.stop_active_and_wait_for_takeover()
}

pub fn take_over_and_return() -> Result<ReturnedGroup, String> {
    start_and_take_over()?.return_the_old_active()
}

pub fn revoke_device(
    hosting: &TestDevice,
    device_id: &str,
) -> Result<(), String> {
    hosting.run(&json!({
        "command": "revoke_device",
        "device_id": device_id,
    }))?;
    Ok(())
}

pub fn read_state_revision(device: &TestDevice) -> Result<u64, String> {
    let state = read_hosted_state(device)?;
    let revision = state["revision"].as_u64();
    revision.ok_or_else(|| MISSING_REVISION.to_owned())
}

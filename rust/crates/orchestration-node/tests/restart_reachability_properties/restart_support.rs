use std::net::{Ipv4Addr, UdpSocket};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

use orchestration_core::peer_address::PeerAddress;
use orchestration_core::server_group::ServerStanding;
use orchestration_node::server_address::ServerAddress;
use serde_json::Value;

use crate::backup_group::BackupGroup;
use crate::hosting_desk::{
    read_hosted_peer_address, read_own_group, use_server_within,
    wait_until_server_standing,
};
use crate::local_announcements::{
    ResolvedAnnouncement, describe_announced_address, watch_for_announcement,
};
use crate::support::hosting_steps::HostingDevice;
use crate::support::server_backups::{
    create_project, read_hosted_state, wait_until_copied,
};
use crate::support::test_device::{TestDevice, describe};
use crate::support::waiting::wait_for;

pub const WATCH_PERIOD: Duration = Duration::from_secs(25);
const REACH_LIMIT: Duration = Duration::from_secs(60);
const REACH_DESCRIPTION: &str = "the moved server to answer a client";
pub const WATCHED_TAKEOVER_SECONDS: u64 = 10;
const PROJECT_PREFIX: &str = "kept-across-a-restart";
const NO_IPV4_PORT: &str = "the hosted peer address has no IPv4 address";

static WRITTEN_PROJECTS: AtomicUsize = AtomicUsize::new(0);

#[derive(Debug)]
pub struct RestartedServer {
    pub device: TestDevice,
    pub old_address: PeerAddress,
    pub taken_port: Option<UdpSocket>,
}

#[derive(Debug)]
pub struct RestartedGroup {
    pub active: RestartedServer,
    pub active_port: u16,
    pub backup: TestDevice,
    pub workspace_id: String,
}

pub fn read_ipv4_peer_port(peer_address: &PeerAddress) -> Result<u16, String> {
    let ipv4_address = peer_address
        .direct_addresses
        .iter()
        .find(|direct_address| direct_address.is_ipv4());
    let ipv4_address = ipv4_address.ok_or_else(|| NO_IPV4_PORT.to_owned())?;
    Ok(ipv4_address.port())
}

pub fn read_hosted_ipv4_port(device: &TestDevice) -> Result<u16, String> {
    let peer_address = read_hosted_peer_address(device)?;
    read_ipv4_peer_port(&peer_address)
}

pub fn restart_keeping_the_port_free(
    device: TestDevice,
) -> Result<RestartedServer, String> {
    let old_address = read_hosted_peer_address(&device)?;
    let device = device.stop_and_start_again()?;
    Ok(RestartedServer {
        device,
        old_address,
        taken_port: None,
    })
}

pub fn restart_with_the_port_taken(
    device: TestDevice,
) -> Result<RestartedServer, String> {
    let old_address = read_hosted_peer_address(&device)?;
    let old_port = read_ipv4_peer_port(&old_address)?;
    let stopped = device.stop();
    let taken_port = UdpSocket::bind((Ipv4Addr::UNSPECIFIED, old_port))
        .map_err(describe)?;
    let device = stopped.start_again()?;
    Ok(RestartedServer {
        device,
        old_address,
        taken_port: Some(taken_port),
    })
}

pub fn restart_the_active(
    group: BackupGroup,
    restart: impl FnOnce(TestDevice) -> Result<RestartedServer, String>,
) -> Result<RestartedGroup, String> {
    let BackupGroup {
        hosting,
        backup,
        workspace_id,
        ..
    } = group;
    let HostingDevice { device, port, .. } = hosting;
    let active = restart(device)?;
    wait_until_server_standing(&active.device, port, ServerStanding::Active)?;
    Ok(RestartedGroup {
        active,
        active_port: port,
        backup,
        workspace_id,
    })
}

pub fn wait_for_the_new_announcement(
    restarted: &RestartedServer,
) -> Result<ResolvedAnnouncement, String> {
    let announced_address = describe_announced_address(&restarted.old_address);
    let (_watch, announced) = watch_for_announcement(&announced_address)?;
    Ok(announced)
}

pub fn check_health_at(address: &PeerAddress) -> Result<(), String> {
    let server_address = ServerAddress::Peer(address.clone());
    use_server_within(&server_address, async |server| {
        server.check_health().await
    })
}

pub fn retry_until_reached<Found>(
    mut reach: impl FnMut() -> Result<Found, String>,
) -> Result<Found, String> {
    wait_for(REACH_LIMIT, REACH_DESCRIPTION, || Ok(reach().ok()))
}

impl RestartedGroup {
    pub fn write_a_project(&self) -> Result<String, String> {
        let number = WRITTEN_PROJECTS.fetch_add(1, Ordering::SeqCst);
        let name = format!("{PROJECT_PREFIX}-{number}");
        create_project(&self.active.device, &self.workspace_id, &name)?;
        Ok(name)
    }

    pub fn wait_until_the_backup_caught_up(&self) -> Result<Value, String> {
        wait_until_copied(&self.active.device, &self.backup)
    }

    pub fn read_active_standing(&self) -> Result<ServerStanding, String> {
        let view = read_own_group(&self.active.device, self.active_port)?;
        Ok(view.standing)
    }

    pub fn read_active_projects(&self) -> Result<String, String> {
        let state = read_hosted_state(&self.active.device)?;
        Ok(state["projects"].to_string())
    }
}

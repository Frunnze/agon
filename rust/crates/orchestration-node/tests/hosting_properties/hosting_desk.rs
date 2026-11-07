use std::fs;
use std::io::{Read, Write};
use std::net::{Ipv4Addr, Shutdown, SocketAddr, TcpStream};
use std::path::{Path, PathBuf};
use std::sync::{Arc, OnceLock};
use std::time::Duration;

use orchestration_api::server_group::ServerGroupView;
use orchestration_core::peer_address::PeerAddress;
use orchestration_core::server_group::ServerStanding;
use orchestration_node::node_error::NodeError;
use orchestration_node::node_runtime::NodeRuntime;
use orchestration_node::server_address::ServerAddress;
use orchestration_node::server_client::{PeerDialer, ServerClient};
use orchestration_p2p::peer_configuration::RelayChoice;
use orchestration_security::identity::DeviceIdentity;
use proptest::test_runner::Config;
use serde_json::{Value, json};
use tempfile::TempDir;
use tokio::time::timeout;

use crate::support::hosting_steps::{
    HostingDevice, read_health_answer, read_hosted_address,
    start_hosting_device,
};
use crate::support::runner_access::test_runtime;
use crate::support::test_device::{RELAY_DISABLED, TestDevice, describe};
use crate::support::waiting::wait_for;

const TARGET_TEMPORARY_FOLDER: &str = env!("CARGO_TARGET_TMPDIR");
const DATA_FOLDER_NAME: &str = "hosting_properties";
const REQUEST_LIMIT: Duration = Duration::from_secs(40);
const LOOPBACK_ADDRESS_PREFIX: &str = "http://127.0.0.1:";
const NOT_A_PEER_ADDRESS: &str = "the hosted address is not a peer address";
const LATE_ANSWER: &str = "the server did not answer in time";
const RUNNER_OFF: &str = "off";
const FILE_IDENTITY_STORE: &str = "file";
const REFRESH_LIMIT: Duration = Duration::from_secs(40);
pub const STANDING_LIMIT: Duration = Duration::from_secs(90);
const HOSTILE_READ_LIMIT: Duration = Duration::from_secs(5);

static SHARED_HOSTING: OnceLock<Result<HostingDevice, String>> =
    OnceLock::new();

pub fn keep_data_in_target() -> Result<(), String> {
    let data_folder =
        PathBuf::from(TARGET_TEMPORARY_FOLDER).join(DATA_FOLDER_NAME);
    fs::create_dir_all(&data_folder).map_err(describe)?;
    match tempfile::env::override_temp_dir(&data_folder) {
        Ok(()) => Ok(()),
        Err(chosen_folder) if chosen_folder == data_folder => Ok(()),
        Err(chosen_folder) => {
            Err(format!("data goes to {}", chosen_folder.display()))
        }
    }
}

pub fn host_a_server() -> Result<HostingDevice, String> {
    keep_data_in_target()?;
    start_hosting_device()
}

pub fn shared_hosting() -> Result<&'static HostingDevice, String> {
    let hosting = SHARED_HOSTING.get_or_init(host_a_server);
    hosting.as_ref().map_err(Clone::clone)
}

pub fn heavy_cases(cases: u32) -> Config {
    Config {
        cases,
        max_shrink_iters: 0,
        ..Config::default()
    }
}

pub fn loopback_address(port: u16) -> ServerAddress {
    ServerAddress::Web(format!("{LOOPBACK_ADDRESS_PREFIX}{port}"))
}

pub fn read_hosted_peer_address(
    device: &TestDevice,
) -> Result<PeerAddress, String> {
    let address_text = read_hosted_address(device)?;
    let parsed = ServerAddress::parse(&address_text).map_err(describe)?;
    let ServerAddress::Peer(peer_address) = parsed else {
        return Err(NOT_A_PEER_ADDRESS.to_owned());
    };
    Ok(peer_address)
}

pub fn use_server_within<Found>(
    address: &ServerAddress,
    use_server: impl AsyncFnOnce(&ServerClient) -> Result<Found, NodeError>,
) -> Result<Found, String> {
    let runtime = test_runtime()?;
    let dialer = Arc::new(PeerDialer::new(RelayChoice::Disabled));
    let server = ServerClient::connect(address, &dialer).map_err(describe)?;
    runtime.block_on(async {
        let bounded = timeout(REQUEST_LIMIT, use_server(&server)).await;
        dialer.close().await;
        let Ok(outcome) = bounded else {
            return Err(LATE_ANSWER.to_owned());
        };
        outcome.map_err(describe)
    })
}

pub fn read_group_with(
    identity: &DeviceIdentity,
    address: &ServerAddress,
) -> Result<ServerGroupView, String> {
    use_server_within(address, async |server| {
        server.signed(identity).read_server_group().await
    })
}

pub fn read_group_at(
    device: &TestDevice,
    address: &ServerAddress,
) -> Result<ServerGroupView, String> {
    let identity = device.load_identity()?;
    read_group_with(&identity, address)
}

pub fn read_own_group(
    device: &TestDevice,
    port: u16,
) -> Result<ServerGroupView, String> {
    read_group_at(device, &loopback_address(port))
}

pub fn hosting_configuration(data_directory: &Path, port: u16) -> Value {
    json!({
        "data_directory": data_directory,
        "identity_store": FILE_IDENTITY_STORE,
        "peer_relay": RELAY_DISABLED,
        "runner": RUNNER_OFF,
        "app_server_port": port,
    })
}

pub fn keeping_configuration(
    data_directory: &Path,
    port: u16,
    takeover_seconds: u64,
) -> Value {
    let mut configuration = hosting_configuration(data_directory, port);
    configuration["server_takeover_seconds"] = json!(takeover_seconds);
    configuration
}

pub fn stop_and_keep_data(device: TestDevice) -> TempDir {
    let TestDevice {
        runtime,
        data_directory,
        ..
    } = device;
    drop(runtime);
    data_directory
}

pub fn start_node_with(configuration: &Value) -> Result<NodeRuntime, String> {
    NodeRuntime::start(&configuration.to_string()).map_err(describe)
}

pub fn describe_current_address(
    device: &TestDevice,
) -> Result<PeerAddress, String> {
    let mut address = read_hosted_peer_address(device)?;
    address.direct_addresses.sort();
    address.direct_addresses.dedup();
    Ok(address)
}

pub fn wait_until_listed_address_is_current(
    listed: &TestDevice,
    viewer: &TestDevice,
    viewer_port: u16,
) -> Result<PeerAddress, String> {
    wait_for(REFRESH_LIMIT, "the listed address to be current", || {
        let current = describe_current_address(listed)?;
        let view = read_own_group(viewer, viewer_port)?;
        let member = view.group.members.into_iter().find(|member| {
            member.address.endpoint_public_key == current.endpoint_public_key
        });
        let is_current =
            member.is_some_and(|member| member.address == current);
        Ok(is_current.then_some(current))
    })
}

pub fn wait_until_server_standing(
    device: &TestDevice,
    port: u16,
    standing: ServerStanding,
) -> Result<ServerGroupView, String> {
    let description = format!("the hosted server to be {standing:?}");
    wait_for(STANDING_LIMIT, &description, || {
        let view = read_own_group(device, port)?;
        let is_reached = view.standing == standing;
        Ok(is_reached.then_some(view))
    })
}

pub fn send_hostile_bytes(
    port: u16,
    hostile_bytes: &[u8],
) -> Result<(), String> {
    let server = SocketAddr::from((Ipv4Addr::LOCALHOST, port));
    let mut connection = TcpStream::connect(server).map_err(describe)?;
    connection
        .set_read_timeout(Some(HOSTILE_READ_LIMIT))
        .map_err(describe)?;
    let _sent = connection.write_all(hostile_bytes);
    let _half_closed = connection.shutdown(Shutdown::Write);
    let mut answer = Vec::new();
    let _answered = connection.read_to_end(&mut answer);
    Ok(())
}

pub fn read_loopback_health(port: u16) -> Result<String, String> {
    read_health_answer(SocketAddr::from((Ipv4Addr::LOCALHOST, port)))
}

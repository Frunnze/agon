use std::io::{Read, Write};
use std::net::{
    IpAddr, Ipv4Addr, SocketAddr, TcpListener, TcpStream, UdpSocket,
};
use std::path::PathBuf;

use orchestration_api::routes::HEALTH;
use orchestration_node::server_address::ServerAddress;
use serde_json::{Value, json};

use super::test_device::{RELAY_DISABLED, TestDevice, describe, read_text};

pub const HOSTED_WORKSPACE_NAME: &str = "personal";
pub const HOSTING_DEVICE_NAME: &str = "main-mac";
pub const NO_SERVER_ACCEPTED_CODE: &str = "no app server accepted the code";
pub const HEALTHY_ANSWER_START: &str = "HTTP/1.1 200";
pub const PEER_SCHEME_PREFIX: &str = "peer://";
const HOSTING_ROLE: &str = "client";
const ANY_FREE_PORT: u16 = 0;
const HOSTED_SERVER_DIRECTORY: &str = "hosted-app-server";
const HOSTED_SERVER_RECORD: &str = "hosted-app-server.json";
const ROUTE_PROBE_ADDRESS: &str = "192.0.2.1:9";

#[derive(Debug)]
pub struct HostingDevice {
    pub device: TestDevice,
    pub account: Value,
    pub port: u16,
}

pub fn pick_free_port() -> Result<u16, String> {
    let listener = TcpListener::bind((Ipv4Addr::UNSPECIFIED, ANY_FREE_PORT))
        .map_err(describe)?;
    let local_address = listener.local_addr().map_err(describe)?;
    Ok(local_address.port())
}

pub fn create_hosted_account(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({
        "command": "create_hosted_account",
        "workspace_name": HOSTED_WORKSPACE_NAME,
        "device_name": HOSTING_DEVICE_NAME,
        "role": HOSTING_ROLE,
    }))
}

pub fn start_hosting_device() -> Result<HostingDevice, String> {
    start_hosting_device_with_relay(RELAY_DISABLED)
}

pub fn start_hosting_device_with_relay(
    peer_relay: &str,
) -> Result<HostingDevice, String> {
    let port = pick_free_port()?;
    let device = TestDevice::start_hosting(port, peer_relay)?;
    let account = create_hosted_account(&device)?;
    Ok(HostingDevice {
        device,
        account,
        port,
    })
}

pub fn read_status(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "status" }))
}

pub fn read_hosted_address(device: &TestDevice) -> Result<String, String> {
    let status = read_status(device)?;
    read_text(&status, "/hosted_server_address")
}

pub fn hosted_server_files(device: &TestDevice) -> [PathBuf; 2] {
    let data_directory = device.data_directory.path();
    [
        data_directory.join(HOSTED_SERVER_DIRECTORY),
        data_directory.join(HOSTED_SERVER_RECORD),
    ]
}

pub fn find_local_network_address() -> Result<IpAddr, String> {
    let probe = UdpSocket::bind((Ipv4Addr::UNSPECIFIED, ANY_FREE_PORT))
        .map_err(describe)?;
    probe.connect(ROUTE_PROBE_ADDRESS).map_err(describe)?;
    let local_address = probe.local_addr().map_err(describe)?;
    Ok(local_address.ip())
}

pub fn read_health_answer(
    socket_address: SocketAddr,
) -> Result<String, String> {
    let mut connection =
        TcpStream::connect(socket_address).map_err(describe)?;
    let request = format!(
        "GET {HEALTH} HTTP/1.1\r\nHost: {socket_address}\r\n\
         Connection: close\r\n\r\n"
    );
    connection.write_all(request.as_bytes()).map_err(describe)?;
    let mut answer = String::new();
    connection.read_to_string(&mut answer).map_err(describe)?;
    Ok(answer)
}

pub fn read_server_identity(
    address: Result<String, String>,
) -> Result<ServerAddress, String> {
    let address_text = address?;
    let parsed = ServerAddress::parse(&address_text).map_err(describe)?;
    Ok(parsed.without_direct_addresses())
}

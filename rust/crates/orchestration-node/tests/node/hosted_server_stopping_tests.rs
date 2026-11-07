use std::sync::Arc;

use chrono::Utc;
use orchestration_api::accounts::PublishPeerAddressRequest;
use orchestration_node::server_address::ServerAddress;
use orchestration_node::server_client::{PeerDialer, ServerClient};
use orchestration_p2p::peer_configuration::RelayChoice;
use orchestration_security::peer_addresses::sign_peer_address;
use serde_json::{Value, json};
use tokio::runtime::Runtime;

use crate::support::hosting_steps::{
    HostingDevice, create_hosted_account, hosted_server_files,
    read_hosted_address, start_hosting_device,
};
use crate::support::runner_access::test_runtime;
use crate::support::test_device::{TestDevice, describe};

const LOOPBACK_ADDRESS_PREFIX: &str = "http://127.0.0.1:";

#[derive(Debug)]
struct OpenConnection {
    runtime: Runtime,
    server: ServerClient,
}

impl OpenConnection {
    fn open(address: &ServerAddress) -> Result<Self, String> {
        let runtime = test_runtime()?;
        let dialer = Arc::new(PeerDialer::new(RelayChoice::Disabled));
        let server =
            ServerClient::connect(address, &dialer).map_err(describe)?;
        runtime.block_on(server.check_health()).map_err(describe)?;
        Ok(Self { runtime, server })
    }

    fn check_health(&self) -> Result<(), String> {
        self.runtime
            .block_on(self.server.check_health())
            .map_err(describe)
    }
}

fn start_hosting() -> HostingDevice {
    let hosting = start_hosting_device();
    let Ok(hosting) = hosting else {
        panic!("the device hosts the app server: {hosting:?}");
    };
    hosting
}

fn loopback_address(hosting: &HostingDevice) -> ServerAddress {
    ServerAddress::Web(format!("{LOOPBACK_ADDRESS_PREFIX}{}", hosting.port))
}

fn open_connection(address: &ServerAddress) -> OpenConnection {
    let connection = OpenConnection::open(address);
    let Ok(connection) = connection else {
        panic!("the hosted server answers before: {connection:?}");
    };
    connection
}

fn forget(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "forget_this_device" }))
}

fn read_hosted_peer_address(device: &TestDevice) -> ServerAddress {
    let address = read_hosted_address(device);
    let parsed =
        address.and_then(|text| ServerAddress::parse(&text).map_err(describe));
    let Ok(parsed) = parsed else {
        panic!("the status names the hosted peer address: {parsed:?}");
    };
    parsed
}

#[test]
fn test_forget_this_device_property_open_loopback_links_stop_answering() {
    let hosting = start_hosting();
    let connection = open_connection(&loopback_address(&hosting));

    let forgotten = forget(&hosting.device);
    let health_after = connection.check_health();

    assert_eq!(forgotten, Ok(Value::Null));
    assert!(health_after.is_err(), "{health_after:?}");
}

#[test]
fn test_forget_this_device_property_open_peer_links_stop_answering() {
    let hosting = start_hosting();
    let peer_address = read_hosted_peer_address(&hosting.device);
    let connection = open_connection(&peer_address);

    let forgotten = forget(&hosting.device);
    let health_after = connection.check_health();

    assert_eq!(forgotten, Ok(Value::Null));
    assert!(health_after.is_err(), "{health_after:?}");
}

#[test]
fn test_forget_this_device_property_late_requests_leave_no_server_files() {
    let hosting = start_hosting();
    let Ok(identity) = hosting.device.load_identity() else {
        panic!("the hosting device has an identity");
    };
    let ServerAddress::Peer(peer_address) =
        read_hosted_peer_address(&hosting.device)
    else {
        panic!("the hosted address is a peer address");
    };
    let connection = open_connection(&loopback_address(&hosting));

    let forgotten = forget(&hosting.device);
    let late_request = PublishPeerAddressRequest {
        address: sign_peer_address(&identity, &peer_address, Utc::now()),
    };
    let late_answer = connection.runtime.block_on(
        connection
            .server
            .signed(&identity)
            .publish_peer_address(&late_request),
    );
    let files_left: Vec<_> = hosted_server_files(&hosting.device)
        .into_iter()
        .filter(|path| path.exists())
        .collect();
    let hosted_again = create_hosted_account(&hosting.device);

    assert_eq!(forgotten, Ok(Value::Null));
    assert!(late_answer.is_err(), "{late_answer:?}");
    assert!(files_left.is_empty(), "{files_left:?}");
    assert!(hosted_again.is_ok(), "{hosted_again:?}");
}

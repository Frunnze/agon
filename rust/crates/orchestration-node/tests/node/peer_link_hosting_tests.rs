use std::net::{Ipv4Addr, SocketAddr, TcpListener};
use std::thread;
use std::time::Duration;

use orchestration_core::peer_address::PeerAddress;
use orchestration_node::node_error::NodeError;
use orchestration_node::server_address::ServerAddress;
use orchestration_node::server_client::ServerClient;
use orchestration_p2p::peer_configuration::RelayChoice;
use serde_json::{Value, json};
use uuid::Uuid;

use crate::support::hosting_steps::{
    HEALTHY_ANSWER_START, PEER_SCHEME_PREFIX, create_hosted_account,
    find_local_network_address, hosted_server_files, read_health_answer,
    read_hosted_address, read_server_identity, read_status,
    start_hosting_device, start_hosting_device_with_relay,
};
use crate::support::pairing_steps::join_at_address;
use crate::support::server_access::{
    check_health_at, use_server_at, use_server_with_relay,
};
use crate::support::test_device::{
    RELAY_DEFAULT, TestDevice, describe, read_text,
};

const NOT_FOUND_ANSWER: &str = "the app server answered 404";
const RELAY_ATTEMPTS: u32 = 30;
const RELAY_ATTEMPT_PAUSE: Duration = Duration::from_secs(1);
const SMALL_STACK_SIZE: usize = 128 * 1024;

fn keep_only_the_server_key(address: &str) -> Result<String, String> {
    let parsed = ServerAddress::parse(address).map_err(describe)?;
    let ServerAddress::Peer(peer_address) = parsed.without_direct_addresses()
    else {
        return Err(format!("{address} is not a peer address"));
    };
    let key_only = PeerAddress {
        relay_url: None,
        ..peer_address
    };
    Ok(ServerAddress::Peer(key_only).to_string())
}

async fn check_health_until_answered(
    server: &ServerClient,
) -> Result<u32, NodeError> {
    let mut last_problem = NodeError::NoAppServer;
    for attempt in 1..=RELAY_ATTEMPTS {
        match server.check_health().await {
            Ok(()) => return Ok(attempt),
            Err(problem) => last_problem = problem,
        }
        tokio::time::sleep(RELAY_ATTEMPT_PAUSE).await;
    }
    Err(last_problem)
}

#[test]
fn test_create_hosted_account_property_the_server_key_alone_reaches_it() {
    let hosting = start_hosting_device_with_relay(RELAY_DEFAULT);
    let Ok(hosting) = hosting else {
        panic!("the device hosts the app server: {hosting:?}");
    };
    let Ok(address) = read_hosted_address(&hosting.device) else {
        panic!("the status names the hosted address");
    };
    let Ok(key_only) = keep_only_the_server_key(&address) else {
        panic!("the hosted address is a peer address: {address}");
    };

    let answered = use_server_with_relay(
        &key_only,
        RelayChoice::Default,
        check_health_until_answered,
    );

    assert!(answered.is_ok(), "{answered:?}");
}

#[test]
fn test_create_hosted_account_property_the_api_answers_over_the_peer_link() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };
    let Ok(address) = read_hosted_address(&hosting.device) else {
        panic!("the status names the hosted address");
    };

    let health = check_health_at(&address);
    let unknown_join = use_server_at(&address, async |server| {
        server.read_join_status(Uuid::new_v4()).await
    });

    assert!(address.starts_with(PEER_SCHEME_PREFIX), "{address}");
    assert_eq!(health, Ok(()));
    let problem = unknown_join.err().unwrap_or_default();
    assert!(problem.starts_with(NOT_FOUND_ANSWER), "{problem}");
}

#[test]
fn test_create_hosted_account_property_the_network_has_no_web_route() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };
    let Ok(network_address) = find_local_network_address() else {
        panic!("this computer has a local network address");
    };

    let from_network =
        read_health_answer(SocketAddr::new(network_address, hosting.port));
    let loopback = SocketAddr::from((Ipv4Addr::LOCALHOST, hosting.port));
    let from_this_computer = read_health_answer(loopback);

    assert!(from_network.is_err(), "{from_network:?}");
    assert!(
        from_this_computer
            .as_ref()
            .is_ok_and(|answer| answer.starts_with(HEALTHY_ANSWER_START)),
        "{from_this_computer:?}"
    );
}

#[test]
fn test_forget_this_device_property_the_hosting_device_stops_its_server() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };
    let address_before = read_hosted_address(&hosting.device);
    let Ok(address_text) = address_before.clone() else {
        panic!("the status names the hosted address");
    };

    let forgotten = hosting
        .device
        .run(&json!({ "command": "forget_this_device" }));
    let status = read_status(&hosting.device);
    let health_after = check_health_at(&address_text);
    let port_was_free =
        TcpListener::bind((Ipv4Addr::LOCALHOST, hosting.port)).is_ok();
    let files_left: Vec<_> = hosted_server_files(&hosting.device)
        .into_iter()
        .filter(|path| path.exists())
        .collect();
    let hosted_again = create_hosted_account(&hosting.device);
    let address_after = read_hosted_address(&hosting.device);

    assert_eq!(forgotten, Ok(Value::Null));
    let Ok(status) = status else {
        panic!("the status answers after forgetting: {status:?}");
    };
    assert_eq!(status["hosted_server_address"], Value::Null);
    assert_eq!(status["account"], Value::Null);
    assert!(health_after.is_err(), "{health_after:?}");
    assert!(port_was_free);
    assert!(files_left.is_empty(), "{files_left:?}");
    assert!(hosted_again.is_ok(), "{hosted_again:?}");
    assert_ne!(
        read_server_identity(address_after),
        read_server_identity(address_before)
    );
}

#[test]
fn test_handle_command_property_a_small_calling_stack_still_joins() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };
    let Ok(joining) = TestDevice::start() else {
        panic!("the joining device starts");
    };
    let Ok(address) = read_hosted_address(&hosting.device) else {
        panic!("the status names the hosted address");
    };
    let Ok(session) =
        hosting.device.run(&json!({ "command": "start_pairing" }))
    else {
        panic!("pairing starts");
    };
    let Ok(code) = read_text(&session, "/display_code") else {
        panic!("the session shows a code");
    };

    let joined = thread::scope(|scope| {
        let small_stack = thread::Builder::new().stack_size(SMALL_STACK_SIZE);
        let joining_thread = small_stack.spawn_scoped(scope, || {
            join_at_address(&joining, &address, &code)
        });
        joining_thread.map(thread::ScopedJoinHandle::join)
    });

    let Ok(Ok(joined)) = joined else {
        panic!("the joining thread finishes");
    };
    assert!(joined.is_ok(), "{joined:?}");
}

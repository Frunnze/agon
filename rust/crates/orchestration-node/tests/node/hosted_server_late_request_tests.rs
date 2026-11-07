use std::fs;
use std::io::{Read, Write};
use std::net::{Ipv4Addr, TcpStream};
use std::path::PathBuf;

use chrono::Utc;
use orchestration_api::accounts::PublishPeerAddressRequest;
use orchestration_api::routes::{
    DEVICE_HEADER, DEVICE_PEER_ADDRESS, NONCE_HEADER, SIGNATURE_HEADER,
    TIMESTAMP_HEADER,
};
use orchestration_node::server_address::ServerAddress;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::peer_addresses::sign_peer_address;
use orchestration_security::request_signing::sign_request;
use serde_json::{Value, json};

use crate::support::hosting_steps::{
    HostingDevice, create_hosted_account, hosted_server_files,
    read_hosted_address, read_server_identity, start_hosting_device,
};
use crate::support::test_device::{TestDevice, describe};

const CONTINUE_ANSWER: &str = "HTTP/1.1 100 Continue\r\n\r\n";
const SUCCESS_ANSWER_START: &str = "HTTP/1.1 2";
const STATE_FILE_NAME: &str = "state.json";
const PUT_METHOD: &str = "PUT";

#[derive(Debug)]
struct HeldRequest {
    connection: TcpStream,
    held_body: Vec<u8>,
}

impl HeldRequest {
    fn start(
        port: u16,
        identity: &DeviceIdentity,
        peer_address: &ServerAddress,
    ) -> Result<Self, String> {
        let ServerAddress::Peer(peer_address) = peer_address else {
            return Err("the hosted address is not a peer address".to_owned());
        };
        let published = sign_peer_address(identity, peer_address, Utc::now());
        let request = PublishPeerAddressRequest { address: published };
        let body = serde_json::to_vec(&request).map_err(describe)?;
        let signature = sign_request(
            identity,
            PUT_METHOD,
            DEVICE_PEER_ADDRESS,
            Utc::now(),
            &body,
        )
        .map_err(describe)?;
        let headers = signature.to_header_values();
        let head = format!(
            "{PUT_METHOD} {DEVICE_PEER_ADDRESS} HTTP/1.1\r\n\
             Host: 127.0.0.1:{port}\r\n\
             Connection: close\r\n\
             Expect: 100-continue\r\n\
             Content-Type: application/json\r\n\
             Content-Length: {}\r\n\
             {DEVICE_HEADER}: {}\r\n\
             {TIMESTAMP_HEADER}: {}\r\n\
             {NONCE_HEADER}: {}\r\n\
             {SIGNATURE_HEADER}: {}\r\n\r\n",
            body.len(),
            headers.device_id,
            headers.timestamp,
            headers.nonce,
            headers.signature,
        );
        let mut connection = TcpStream::connect((Ipv4Addr::LOCALHOST, port))
            .map_err(describe)?;
        connection.write_all(head.as_bytes()).map_err(describe)?;
        let mut continue_answer = [0_u8; CONTINUE_ANSWER.len()];
        connection
            .read_exact(&mut continue_answer)
            .map_err(describe)?;
        if continue_answer != CONTINUE_ANSWER.as_bytes() {
            return Err("the server did not start reading the body".into());
        }
        Ok(Self {
            connection,
            held_body: body,
        })
    }

    fn finish(mut self) -> Result<String, String> {
        self.connection
            .write_all(&self.held_body)
            .map_err(describe)?;
        let mut answer = String::new();
        self.connection
            .read_to_string(&mut answer)
            .map_err(describe)?;
        Ok(answer)
    }
}

fn start_hosting() -> HostingDevice {
    let hosting = start_hosting_device();
    let Ok(hosting) = hosting else {
        panic!("the device hosts the app server: {hosting:?}");
    };
    hosting
}

fn hold_a_request(hosting: &HostingDevice) -> HeldRequest {
    let identity = hosting.device.load_identity();
    let address = read_server_identity(read_hosted_address(&hosting.device));
    let held = identity.and_then(|identity| {
        let peer_address = address?;
        HeldRequest::start(hosting.port, &identity, &peer_address)
    });
    let Ok(held) = held else {
        panic!("a request to the hosted server is under way: {held:?}");
    };
    held
}

fn forget(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "forget_this_device" }))
}

fn list_present_files(device: &TestDevice) -> Vec<PathBuf> {
    hosted_server_files(device)
        .into_iter()
        .filter(|path| path.exists())
        .collect()
}

fn is_success(answer: &Result<String, String>) -> bool {
    answer
        .as_ref()
        .is_ok_and(|text| text.starts_with(SUCCESS_ANSWER_START))
}

#[test]
fn test_hosted_app_server_stop_property_late_requests_restore_no_files() {
    let hosting = start_hosting();
    let held = hold_a_request(&hosting);

    let forgotten = forget(&hosting.device);
    let late_answer = held.finish();
    let files_left = list_present_files(&hosting.device);

    assert_eq!(forgotten, Ok(Value::Null));
    assert!(!is_success(&late_answer), "{late_answer:?}");
    assert!(files_left.is_empty(), "{files_left:?}");
}

#[test]
fn test_hosted_app_server_stop_property_hosting_again_skips_late_requests() {
    let hosting = start_hosting();
    let address_before = read_hosted_address(&hosting.device);
    let held = hold_a_request(&hosting);

    let forgotten = forget(&hosting.device);
    let late_answer = held.finish();
    let hosted_again = create_hosted_account(&hosting.device);
    let address_after = read_hosted_address(&hosting.device);

    assert_eq!(forgotten, Ok(Value::Null));
    assert!(!is_success(&late_answer), "{late_answer:?}");
    assert!(hosted_again.is_ok(), "{hosted_again:?}");
    assert_ne!(
        read_server_identity(address_after),
        read_server_identity(address_before)
    );
}

#[test]
fn test_hosted_app_server_stop_property_runtime_stop_saves_no_late_request() {
    let hosting = start_hosting();
    let [server_directory, _record] = hosted_server_files(&hosting.device);
    let state_path = server_directory.join(STATE_FILE_NAME);
    let held = hold_a_request(&hosting);

    let stopped = hosting.device.stop();
    let state_at_stop = fs::read(&state_path);
    let late_answer = held.finish();
    let state_after = fs::read(&state_path);
    drop(stopped);

    assert!(state_at_stop.is_ok(), "{state_at_stop:?}");
    assert!(!is_success(&late_answer), "{late_answer:?}");
    assert_eq!(state_after.ok(), state_at_stop.ok());
}

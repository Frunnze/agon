use std::net::{Ipv4Addr, TcpListener};

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::hosting_steps::{
    HOSTED_WORKSPACE_NAME, HOSTING_DEVICE_NAME, PEER_SCHEME_PREFIX,
    create_hosted_account, pick_free_port, read_hosted_address,
    read_server_identity, read_status, start_hosting_device,
};
use crate::support::server_access::check_health_at;
use crate::support::test_device::{TestDevice, fail, read_text};

const INVALID_NAME_CASES: u32 = 6;
const PORT_TAKEN_TEXT: &str = "already in use";
const ACCOUNT_EXISTS: &str = "this device already has an account";

fn invalid_workspace_name_strategy() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(String::new()),
        "[A-Z]{1,12}",
        "[a-z]{1,8} [a-z]{1,8}",
        "[a-z]{41,50}",
    ]
}

#[test]
fn test_create_hosted_account_property_the_embedded_server_answers() {
    let hosting = start_hosting_device();
    let Ok(hosting) = hosting else {
        panic!("the device hosts the app server: {hosting:?}");
    };

    let address = read_hosted_address(&hosting.device);
    let status = read_status(&hosting.device);

    let Ok(address) = address else {
        panic!("the status names the hosted address: {address:?}");
    };
    let health = check_health_at(&address);
    assert_eq!(
        hosting.account["workspaces"][0]["name"],
        HOSTED_WORKSPACE_NAME
    );
    assert_eq!(hosting.account["device"]["name"], HOSTING_DEVICE_NAME);
    assert!(address.starts_with(PEER_SCHEME_PREFIX), "{address}");
    assert_eq!(health, Ok(()));
    let reachable = status.map(|status| status["server_reachable"].clone());
    assert_eq!(reachable, Ok(json!(true)));
}

#[test]
fn test_create_hosted_account_property_a_restart_brings_the_server_back() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };
    let address_before = read_hosted_address(&hosting.device);
    let device_id = read_text(&hosting.account, "/device/id");

    let restarted = hosting.device.stop_and_start_again();

    let Ok(restarted) = restarted else {
        panic!("the node starts again: {restarted:?}");
    };
    let status = read_status(&restarted);
    let workspaces = restarted.run(&json!({ "command": "list_workspaces" }));
    let Ok(status) = status else {
        panic!("the status answers: {status:?}");
    };
    assert_eq!(status["server_reachable"], true);
    assert_eq!(read_text(&status, "/account/device/id"), device_id);
    let address_after = read_text(&status, "/hosted_server_address");
    assert_eq!(
        read_server_identity(address_after),
        read_server_identity(address_before)
    );
    let first_name =
        workspaces.map(|found| found[0]["workspace"]["name"].clone());
    assert_eq!(first_name, Ok(json!(HOSTED_WORKSPACE_NAME)));
}

#[test]
fn test_create_hosted_account_property_a_taken_port_gives_a_clear_error() {
    let Ok(port) = pick_free_port() else {
        panic!("a free port is found");
    };
    let Ok(_occupied) = TcpListener::bind((Ipv4Addr::LOCALHOST, port)) else {
        panic!("another program takes the port");
    };
    let Ok(device) = TestDevice::start_hosting_on(port) else {
        panic!("the device starts");
    };

    let created = create_hosted_account(&device);
    let status = read_status(&device);

    let Err(problem) = created else {
        panic!("hosting on a taken port is refused: {created:?}");
    };
    assert!(problem.contains(PORT_TAKEN_TEXT), "{problem}");
    assert!(problem.contains(&port.to_string()), "{problem}");
    let Ok(status) = status else {
        panic!("the status answers: {status:?}");
    };
    assert_eq!(status["hosted_server_address"], Value::Null);
    assert_eq!(status["account"], Value::Null);
}

#[test]
fn test_create_hosted_account_property_a_second_account_is_refused() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };

    let second = create_hosted_account(&hosting.device);

    assert_eq!(second, Err(ACCOUNT_EXISTS.to_owned()));
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(INVALID_NAME_CASES))]

    #[test]
    fn test_create_hosted_account_property_invalid_names_never_host(
        workspace_name in invalid_workspace_name_strategy(),
    ) {
        let port = pick_free_port().map_err(fail)?;
        let device = TestDevice::start_hosting_on(port).map_err(fail)?;

        let created = device.run(&json!({
            "command": "create_hosted_account",
            "workspace_name": workspace_name,
            "device_name": HOSTING_DEVICE_NAME,
            "role": "client",
        }));
        let status = read_status(&device).map_err(fail)?;
        let port_is_free = TcpListener::bind((Ipv4Addr::UNSPECIFIED, port));

        prop_assert!(created.is_err());
        prop_assert_eq!(&status["hosted_server_address"], &Value::Null);
        prop_assert!(port_is_free.is_ok());
    }
}

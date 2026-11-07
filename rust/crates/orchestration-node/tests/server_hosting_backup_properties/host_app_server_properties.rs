use std::net::{Ipv4Addr, TcpListener};

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::hosted_files::{
    is_port_free, list_left_server_files, loopback_address,
    pick_two_free_ports, read_record_port, write_hosted_record,
};
use crate::support::hosting_steps::{
    HOSTING_DEVICE_NAME, create_hosted_account, pick_free_port,
    read_hosted_address, read_server_identity, start_hosting_device,
};
use crate::support::server_access::check_health_at;
use crate::support::test_device::{TestDevice, fail};

const HOSTING_CASES: u32 = 4;
const HOSTING_ROLE: &str = "client";

fn valid_workspace_name_strategy() -> impl Strategy<Value = String> {
    "[a-z]{1,12}"
}

fn host_workspace(
    device: &TestDevice,
    workspace_name: &str,
) -> Result<Value, String> {
    device.run(&json!({
        "command": "create_hosted_account",
        "workspace_name": workspace_name,
        "device_name": HOSTING_DEVICE_NAME,
        "role": HOSTING_ROLE,
    }))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOSTING_CASES))]

    #[test]
    fn test_host_app_server_property_a_running_server_is_reused(
        workspace_name in valid_workspace_name_strategy(),
    ) {
        let (configured_port, recorded_port) =
            pick_two_free_ports().map_err(fail)?;
        let device =
            TestDevice::start_hosting_on(configured_port).map_err(fail)?;
        write_hosted_record(&device, recorded_port).map_err(fail)?;
        let device = device.stop_and_start_again().map_err(fail)?;
        let address_before = read_hosted_address(&device);

        let hosted = host_workspace(&device, &workspace_name);
        let address_after = read_hosted_address(&device);

        prop_assert!(hosted.is_ok(), "{:?}", hosted);
        prop_assert!(address_before.is_ok(), "{:?}", address_before);
        prop_assert_eq!(
            read_server_identity(address_after),
            read_server_identity(address_before)
        );
        prop_assert!(is_port_free(configured_port));
        prop_assert_eq!(read_record_port(&device), Ok(recorded_port));
        let health = check_health_at(&loopback_address(recorded_port));
        prop_assert_eq!(health, Ok(()));
    }

    #[test]
    fn test_host_app_server_property_a_taken_port_leaves_nothing_behind(
        workspace_name in valid_workspace_name_strategy(),
    ) {
        let port = pick_free_port().map_err(fail)?;
        let occupied =
            TcpListener::bind((Ipv4Addr::LOCALHOST, port)).map_err(fail)?;
        let device = TestDevice::start_hosting_on(port).map_err(fail)?;

        let refused = host_workspace(&device, &workspace_name);
        let left_files = list_left_server_files(&device);
        drop(occupied);
        let retried = host_workspace(&device, &workspace_name);

        prop_assert!(refused.is_err(), "{:?}", refused);
        prop_assert!(left_files.is_empty(), "{:?}", left_files);
        prop_assert!(retried.is_ok(), "{:?}", retried);
        prop_assert_eq!(read_record_port(&device), Ok(port));
    }
}

#[test]
fn test_host_app_server_property_the_record_names_the_configured_port() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };

    let recorded_port = read_record_port(&hosting.device);
    let health = check_health_at(&loopback_address(hosting.port));
    let second_host = create_hosted_account(&hosting.device);
    let recorded_after = read_record_port(&hosting.device);

    assert_eq!(recorded_port, Ok(hosting.port));
    assert_eq!(health, Ok(()));
    assert!(second_host.is_err(), "{second_host:?}");
    assert_eq!(recorded_after, Ok(hosting.port));
}

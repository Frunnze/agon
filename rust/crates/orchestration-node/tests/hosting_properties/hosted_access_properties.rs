use std::thread;
use std::time::Duration;

use orchestration_core::server_group::ServerGroup;
use orchestration_node::device_files::DeviceFiles;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::backup_group::{shared_backup_group, take_over_and_return};
use crate::hosting_desk::{
    heavy_cases, host_a_server, keep_data_in_target, loopback_address,
    read_own_group, shared_hosting, wait_until_listed_address_is_current,
};
use crate::support::hosting_steps::{
    HostingDevice, create_hosted_account, hosted_server_files, read_status,
};
use crate::support::test_device::{TestDevice, fail, read_text};

const ACCOUNT_EXISTS: &str = "this device already has an account";
const AFTER_FORGETTING: Duration = Duration::from_secs(7);
const JOINING_NAME: &str = "spare-laptop";
const JOINING_WORKSPACE: &str = "spare";

fn load_saved_group(
    device: &TestDevice,
) -> Result<ServerGroup, TestCaseError> {
    let files =
        DeviceFiles::open(device.data_directory.path()).map_err(fail)?;
    let saved = files.load_server_group().map_err(fail)?;
    saved.ok_or_else(|| fail("the device saved no server group"))
}

fn read_reachable(device: &TestDevice) -> Result<Value, TestCaseError> {
    let status = read_status(device).map_err(fail)?;
    Ok(status["server_reachable"].clone())
}

proptest! {
    #![proptest_config(heavy_cases(2))]

    #[test]
    fn test_hosted_app_server_own_route_property_the_host_reaches_itself(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        let reachable = read_reachable(&hosting.device)?;

        prop_assert_eq!(reachable, Value::Bool(true));
    }

    #[test]
    fn test_hosted_app_server_own_route_property_restarts_stay_connected(
        restart_count in 1_usize..3,
    ) {
        let HostingDevice { mut device, .. } = host_a_server().map_err(fail)?;

        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
            prop_assert_eq!(read_reachable(&device)?, Value::Bool(true));
        }
    }

    #[test]
    fn test_hosted_app_server_own_route_property_a_new_active_reaches_itself(
        _round in 0_u8..1,
    ) {
        let returned = take_over_and_return().map_err(fail)?;

        let active_reachable = read_reachable(&returned.active)?;
        let returned_reachable = read_reachable(&returned.returned)?;

        prop_assert_eq!(active_reachable, Value::Bool(true));
        prop_assert_eq!(returned_reachable, Value::Bool(true));
    }

    #[test]
    fn test_hosted_app_server_describe_access_property_uses_the_loopback(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        let status = read_status(&hosting.device).map_err(fail)?;

        let server_address =
            read_text(&status, "/server_address").map_err(fail)?;
        prop_assert_eq!(
            server_address,
            loopback_address(hosting.port).to_string()
        );
    }

    #[test]
    fn test_hosted_app_server_describe_access_property_the_code_is_spent(
        setup_code in "[A-Z0-9]{4,12}",
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        keep_data_in_target().map_err(fail)?;
        let joining = TestDevice::start().map_err(fail)?;

        let created = joining.run(&json!({
            "command": "create_account",
            "server_address": loopback_address(hosting.port).to_string(),
            "setup_code": setup_code,
            "device_name": JOINING_NAME,
            "role": "client",
            "workspace_name": JOINING_WORKSPACE,
        }));

        prop_assert!(created.is_err(), "{created:?}");
    }

    #[test]
    fn test_hosted_app_server_describe_access_property_hosts_only_once(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let before = read_status(&hosting.device).map_err(fail)?;

        let again = create_hosted_account(&hosting.device);
        let after = read_status(&hosting.device).map_err(fail)?;

        prop_assert_eq!(again, Err(ACCOUNT_EXISTS.to_owned()));
        prop_assert_eq!(
            &after["hosted_server_address"],
            &before["hosted_server_address"]
        );
    }

    #[test]
    fn test_hosted_app_server_is_keeping_property_hosting_founds_at_once(
        _round in 0_u8..2,
    ) {
        let hosting = host_a_server().map_err(fail)?;

        let view =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;

        prop_assert!(view.group.term.is_some());
        prop_assert_eq!(view.group.members.len(), 1);
    }

    #[test]
    fn test_hosted_app_server_is_keeping_property_a_restart_saves_the_group(
        restart_count in 1_usize..3,
    ) {
        let HostingDevice { mut device, port, .. } =
            host_a_server().map_err(fail)?;

        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
            let saved = load_saved_group(&device)?;
            let view = read_own_group(&device, port).map_err(fail)?;
            prop_assert_eq!(&saved.term, &view.group.term);
        }
    }

    #[test]
    fn test_hosted_app_server_is_keeping_property_a_backup_saves_the_pair(
        _round in 0_u8..1,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        let saved = load_saved_group(&group.backup)?;

        prop_assert_eq!(saved.members.len(), 2);
        prop_assert!(saved.term.is_some());
    }

    #[test]
    fn test_hosted_app_server_start_keeping_property_refreshes_after_restart(
        _round in 0_u8..1,
    ) {
        let HostingDevice { device, port, .. } =
            host_a_server().map_err(fail)?;

        let device = device.stop_and_start_again().map_err(fail)?;
        let current =
            wait_until_listed_address_is_current(&device, &device, port);

        prop_assert!(current.is_ok(), "{current:?}");
    }

    #[test]
    fn test_hosted_app_server_start_keeping_property_the_backup_copies(
        _round in 0_u8..1,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        let copied = group.write_and_wait_for_copy();

        prop_assert!(copied.is_ok(), "{copied:?}");
    }

    #[test]
    fn test_hosted_app_server_start_keeping_property_ends_when_forgotten(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;

        let forgotten = hosting
            .device
            .run(&json!({ "command": "forget_this_device" }));
        thread::sleep(AFTER_FORGETTING);

        prop_assert_eq!(forgotten, Ok(Value::Null));
        for path in hosted_server_files(&hosting.device) {
            prop_assert!(!path.exists(), "{path:?}");
        }
    }
}

use std::fs;

use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::Value;

use crate::backup_group::{
    STEADY_TAKEOVER_SECONDS, pair_a_keeping_device, shared_backup_group,
};
use crate::hosting_desk::{
    heavy_cases, host_a_server, read_own_group, shared_hosting,
    wait_until_listed_address_is_current,
};
use crate::support::hosting_steps::{HostingDevice, hosted_server_files};
use crate::support::server_backups::{read_app_servers, start_server_backup};
use crate::support::test_device::{TestDevice, fail};

const SERVER_FAILED_START: &str = "the app server on this device failed: ";
const SERVER_KEY_FILE_NAME: &str = "server-identity.key";
const STATE_FILE_NAME: &str = "state.json";

fn damaged_key_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..20)
}

fn refuse_backup(device: &TestDevice) -> Result<String, TestCaseError> {
    match start_server_backup(device) {
        Ok(view) => Err(fail(format!("the backup started: {view}"))),
        Err(problem) => Ok(problem),
    }
}

proptest! {
    #![proptest_config(heavy_cases(2))]

    #[test]
    fn test_describe_own_address_property_sorts_and_dedups_every_member(
        _round in 0_u8..2,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        let view = group.read_active_group().map_err(fail)?;

        for member in &view.group.members {
            let direct_addresses = &member.address.direct_addresses;
            prop_assert!(!direct_addresses.is_empty());
            for pair in direct_addresses.windows(2) {
                prop_assert!(pair[0] < pair[1], "{direct_addresses:?}");
            }
        }
    }

    #[test]
    fn test_describe_own_address_property_holds_the_hosted_address(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        let current =
            wait_until_listed_address_is_current(
                &hosting.device,
                &hosting.device,
                hosting.port,
            );

        prop_assert!(current.is_ok(), "{current:?}");
    }

    #[test]
    fn test_describe_own_address_property_a_restart_refreshes_the_member(
        restart_count in 1_usize..3,
    ) {
        let HostingDevice { mut device, port, .. } =
            host_a_server().map_err(fail)?;

        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
            let current =
                wait_until_listed_address_is_current(&device, &device, port);
            prop_assert!(current.is_ok(), "{current:?}");
        }
    }

    #[test]
    fn test_describe_server_problem_property_a_damaged_server_key_is_named(
        damaged_key in damaged_key_strategy(),
    ) {
        let paired =
            pair_a_keeping_device(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let [server_directory, _record] = hosted_server_files(&paired.device);
        fs::create_dir_all(&server_directory).map_err(fail)?;
        let key_path = server_directory.join(SERVER_KEY_FILE_NAME);
        fs::write(&key_path, &damaged_key).map_err(fail)?;

        let problem = refuse_backup(&paired.device)?;
        let view = read_own_group(&paired.hosting.device, paired.hosting.port)
            .map_err(fail)?;

        prop_assert!(problem.starts_with(SERVER_FAILED_START), "{problem}");
        prop_assert_eq!(view.group.members.len(), 1);
    }

    #[test]
    fn test_describe_server_problem_property_a_failed_copy_is_undone(
        _round in 0_u8..2,
    ) {
        let paired =
            pair_a_keeping_device(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let server_files = hosted_server_files(&paired.device);
        let [server_directory, _record] = &server_files;
        fs::create_dir_all(server_directory.join(STATE_FILE_NAME))
            .map_err(fail)?;

        let problem = refuse_backup(&paired.device)?;
        let view = read_own_group(&paired.hosting.device, paired.hosting.port)
            .map_err(fail)?;
        let servers = read_app_servers(&paired.device).map_err(fail)?;

        prop_assert!(problem.starts_with(SERVER_FAILED_START), "{problem}");
        prop_assert_eq!(view.group.members.len(), 1);
        for path in &server_files {
            prop_assert!(!path.exists(), "{path:?}");
        }
        prop_assert_eq!(&servers["this_device"], &Value::from("none"));
    }

    #[test]
    fn test_describe_server_problem_property_a_repaired_device_starts(
        damaged_key in damaged_key_strategy(),
    ) {
        let paired =
            pair_a_keeping_device(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let [server_directory, _record] = hosted_server_files(&paired.device);
        fs::create_dir_all(&server_directory).map_err(fail)?;
        let key_path = server_directory.join(SERVER_KEY_FILE_NAME);
        fs::write(&key_path, &damaged_key).map_err(fail)?;

        refuse_backup(&paired.device)?;
        fs::remove_file(&key_path).map_err(fail)?;
        let started = start_server_backup(&paired.device).map_err(fail)?;

        prop_assert_eq!(&started["this_device"], &Value::from("backup"));
    }
}

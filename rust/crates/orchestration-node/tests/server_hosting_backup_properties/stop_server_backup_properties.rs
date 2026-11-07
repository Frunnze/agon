use proptest::prelude::*;
use serde_json::Value;

use crate::backup_fixtures::{
    STEADY_TAKEOVER_SECONDS, list_server_device_ids, pair_backup_device,
    read_own_standing,
};
use crate::hosted_files::{
    is_port_free, list_left_server_files, loopback_address, read_record_port,
};
use crate::support::hosting_steps::pick_free_port;
use crate::support::server_access::check_health_at;
use crate::support::server_backups::{
    start_server_backup, stop_server_backup,
};
use crate::support::test_device::{TestDevice, fail};

const STOP_CASES: u32 = 2;
const NOT_KEEPING_REFUSAL: &str = "this device keeps no app server";
const ACTIVE_REFUSAL: &str = "this device is the active app server";
const NO_ACCOUNT_REFUSAL: &str = "this device has no account yet";
const ACTIVE_STANDING: &str = "active";
const NO_STANDING: &str = "none";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STOP_CASES))]

    #[test]
    fn test_stop_server_backup_property_keeping_nothing_is_refused(
        attempt_count in 1_usize..3,
    ) {
        let group = pair_backup_device().map_err(fail)?;

        for _ in 0..attempt_count {
            let refused = stop_server_backup(&group.backup);
            prop_assert_eq!(refused, Err(NOT_KEEPING_REFUSAL.to_owned()));
        }

        let listed = list_server_device_ids(&group.hosting.device);
        prop_assert_eq!(listed.map(|device_ids| device_ids.len()), Ok(1));
        prop_assert!(list_left_server_files(&group.backup).is_empty());
    }

    #[test]
    fn test_stop_server_backup_property_no_account_is_refused(
        attempt_count in 1_usize..3,
    ) {
        let port = pick_free_port().map_err(fail)?;
        let device = TestDevice::start_keeping(port, STEADY_TAKEOVER_SECONDS)
            .map_err(fail)?;

        for _ in 0..attempt_count {
            let refused = stop_server_backup(&device);
            prop_assert_eq!(refused, Err(NO_ACCOUNT_REFUSAL.to_owned()));
        }

        prop_assert!(list_left_server_files(&device).is_empty());
    }
}

#[test]
fn test_stop_server_backup_property_the_active_server_keeps_serving() {
    let Ok(group) = pair_backup_device() else {
        panic!("the backup device pairs with the hosting device");
    };
    let started = start_server_backup(&group.backup);
    assert!(started.is_ok(), "{started:?}");

    let refused = stop_server_backup(&group.hosting.device);
    let health = check_health_at(&loopback_address(group.hosting.port));
    let listed = list_server_device_ids(&group.hosting.device);
    let standing = read_own_standing(&group.hosting.device);

    assert_eq!(refused, Err(ACTIVE_REFUSAL.to_owned()));
    assert_eq!(health, Ok(()));
    assert_eq!(listed.map(|device_ids| device_ids.len()), Ok(2));
    assert_eq!(standing, Ok(Value::from(ACTIVE_STANDING)));
    let recorded_port = read_record_port(&group.hosting.device);
    assert_eq!(recorded_port, Ok(group.hosting.port));
}

#[test]
fn test_stop_server_backup_property_a_stopped_backup_stays_stopped() {
    let Ok(group) = pair_backup_device() else {
        panic!("the backup device pairs with the hosting device");
    };
    let started = start_server_backup(&group.backup);
    assert!(started.is_ok(), "{started:?}");
    let stopped = stop_server_backup(&group.backup);
    assert!(stopped.is_ok(), "{stopped:?}");

    let restarted = group.backup.stop_and_start_again();

    let Ok(restarted) = restarted else {
        panic!("the stopped backup starts again: {restarted:?}");
    };
    let standing = read_own_standing(&restarted);
    let listed = list_server_device_ids(&group.hosting.device);
    assert_eq!(standing, Ok(Value::from(NO_STANDING)));
    assert_eq!(listed.map(|device_ids| device_ids.len()), Ok(1));
    assert!(is_port_free(group.backup_port));
    let left_files = list_left_server_files(&restarted);
    assert!(left_files.is_empty(), "{left_files:?}");
}

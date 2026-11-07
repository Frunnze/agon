use std::fs;
use std::net::{Ipv4Addr, TcpListener};

use proptest::prelude::*;
use serde_json::Value;
use tempfile::TempDir;

use crate::backup_fixtures::{
    list_server_device_ids, pair_backup_device, read_own_standing,
};
use crate::hosted_files::{
    is_port_free, loopback_address, pick_two_free_ports, write_hosted_record,
};
use crate::runtime_steps::{
    host_on, hosted_record_in, read_hosted_address_on, start_runtime,
};
use crate::support::hosting_steps::{
    pick_free_port, read_server_identity, read_status,
};
use crate::support::server_access::check_health_at;
use crate::support::server_backups::start_server_backup;
use crate::support::test_device::{TestDevice, fail};

const RESTART_CASES: u32 = 4;
const BACKUP_STANDING: &str = "backup";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RESTART_CASES))]

    #[test]
    fn test_restart_recorded_app_server_property_no_record_hosts_nothing(
        restart_count in 1_usize..3,
    ) {
        let port = pick_free_port().map_err(fail)?;
        let mut device = TestDevice::start_hosting_on(port).map_err(fail)?;
        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
        }

        let status = read_status(&device).map_err(fail)?;

        prop_assert_eq!(&status["hosted_server_address"], &Value::Null);
        prop_assert!(is_port_free(port));
    }

    #[test]
    fn test_restart_recorded_app_server_property_the_record_port_wins(
        restart_count in 1_usize..3,
    ) {
        let (configured_port, recorded_port) =
            pick_two_free_ports().map_err(fail)?;
        let mut device =
            TestDevice::start_hosting_on(configured_port).map_err(fail)?;
        write_hosted_record(&device, recorded_port).map_err(fail)?;
        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
        }

        let status = read_status(&device).map_err(fail)?;
        let health = check_health_at(&loopback_address(recorded_port));

        prop_assert!(status["hosted_server_address"].is_string());
        prop_assert_eq!(health, Ok(()));
        prop_assert!(is_port_free(configured_port));
    }
}

#[test]
fn test_restart_recorded_app_server_property_a_taken_port_loses_nothing() {
    let data_directory = TempDir::new();
    let Ok(data_directory) = data_directory else {
        panic!("the data directory is made: {data_directory:?}");
    };
    let Ok(port) = pick_free_port() else {
        panic!("a free port is found");
    };
    let Ok(first_runtime) = start_runtime(data_directory.path(), port) else {
        panic!("the node starts");
    };
    let hosted = host_on(&first_runtime);
    assert!(hosted.is_ok(), "{hosted:?}");
    let address_before = read_hosted_address_on(&first_runtime);
    drop(first_runtime);
    let record_path = hosted_record_in(data_directory.path());
    let record_before = fs::read(&record_path).ok();
    let Ok(occupied) = TcpListener::bind((Ipv4Addr::LOCALHOST, port)) else {
        panic!("another program takes the port");
    };

    let started_anyway = start_runtime(data_directory.path(), port);
    let record_after_taken_start = fs::read(&record_path).ok();
    let Ok(started_anyway) = started_anyway else {
        panic!("the node starts while the port is taken: {started_anyway:?}");
    };
    drop(started_anyway);
    drop(occupied);
    let restarted = start_runtime(data_directory.path(), port);

    assert!(record_before.is_some());
    assert_eq!(record_after_taken_start, record_before);
    let Ok(restarted) = restarted else {
        panic!("the node starts once the port is free: {restarted:?}");
    };
    let address_after = read_hosted_address_on(&restarted);
    assert_eq!(
        read_server_identity(address_after),
        read_server_identity(address_before)
    );
}

#[test]
fn test_restart_recorded_app_server_property_a_backup_returns_as_a_backup() {
    let Ok(group) = pair_backup_device() else {
        panic!("the backup device pairs with the hosting device");
    };
    let started = start_server_backup(&group.backup);
    assert!(started.is_ok(), "{started:?}");

    let restarted = group.backup.stop_and_start_again();

    let Ok(restarted) = restarted else {
        panic!("the backup device starts again: {restarted:?}");
    };
    let standing = read_own_standing(&restarted);
    let listed = list_server_device_ids(&group.hosting.device);
    assert_eq!(standing, Ok(Value::from(BACKUP_STANDING)));
    assert_eq!(listed.map(|device_ids| device_ids.len()), Ok(2));
    assert!(!is_port_free(group.backup_port));
}

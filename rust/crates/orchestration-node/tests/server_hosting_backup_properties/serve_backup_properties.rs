use std::fs;

use proptest::prelude::*;
use serde_json::Value;

use crate::backup_fixtures::{pair_backup_device, read_own_standing};
use crate::folder_locks::{
    OPEN_FOLDER_MODE, READ_ONLY_FOLDER_MODE, set_folder_mode,
};
use crate::hosted_files::{
    hosted_server_directory, hosted_server_record, is_port_free,
    read_record_port,
};
use crate::support::hosting_steps::{PEER_SCHEME_PREFIX, read_status};
use crate::support::server_backups::{
    start_server_backup, stop_server_backup,
};
use crate::support::test_device::{TestDevice, fail, read_text};

const SERVE_CASES: u32 = 2;
const NO_STANDING: &str = "none";

fn read_hosted_address_value(device: &TestDevice) -> Result<Value, String> {
    let status = read_status(device)?;
    Ok(status["hosted_server_address"].clone())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SERVE_CASES))]

    #[test]
    fn test_serve_backup_property_each_start_serves_one_recorded_standby(
        cycle_count in 1_usize..4,
    ) {
        let group = pair_backup_device().map_err(fail)?;

        for _ in 0..cycle_count {
            start_server_backup(&group.backup).map_err(fail)?;
            let recorded_port = read_record_port(&group.backup);
            prop_assert_eq!(recorded_port, Ok(group.backup_port));
            prop_assert!(!is_port_free(group.backup_port));

            stop_server_backup(&group.backup).map_err(fail)?;
            prop_assert!(!hosted_server_record(&group.backup).exists());
            prop_assert!(is_port_free(group.backup_port));
        }
    }
}

#[test]
fn test_serve_backup_property_the_standby_names_its_peer_address() {
    let Ok(group) = pair_backup_device() else {
        panic!("the backup device pairs with the hosting device");
    };
    let address_before = read_hosted_address_value(&group.backup);

    let started = start_server_backup(&group.backup);
    let status = read_status(&group.backup);

    assert!(started.is_ok(), "{started:?}");
    assert_eq!(address_before, Ok(Value::Null));
    let Ok(status) = status else {
        panic!("the status answers: {status:?}");
    };
    let address = read_text(&status, "/hosted_server_address");
    let Ok(address) = address else {
        panic!("the standby server has an address: {status}");
    };
    assert!(address.starts_with(PEER_SCHEME_PREFIX), "{address}");
}

#[test]
fn test_serve_backup_property_an_unsaved_record_stops_the_standby() {
    let Ok(group) = pair_backup_device() else {
        panic!("the backup device pairs with the hosting device");
    };
    let data_directory = group.backup.data_directory.path();
    let made = fs::create_dir_all(hosted_server_directory(&group.backup));
    assert!(made.is_ok(), "{made:?}");
    let locked = set_folder_mode(data_directory, READ_ONLY_FOLDER_MODE);
    assert_eq!(locked, Ok(()));

    let refused = start_server_backup(&group.backup);
    let unlocked = set_folder_mode(data_directory, OPEN_FOLDER_MODE);
    let hosted_address = read_hosted_address_value(&group.backup);
    let standing = read_own_standing(&group.backup);

    assert!(refused.is_err(), "{refused:?}");
    assert_eq!(unlocked, Ok(()));
    assert_eq!(hosted_address, Ok(Value::Null));
    assert_eq!(standing, Ok(Value::from(NO_STANDING)));
    assert!(is_port_free(group.backup_port));
}

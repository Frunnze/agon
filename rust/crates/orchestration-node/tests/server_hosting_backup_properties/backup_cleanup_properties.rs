use std::fs;
use std::net::{Ipv4Addr, TcpListener};

use serde_json::Value;

use crate::backup_fixtures::{
    BackupGroup, list_server_device_ids, pair_backup_device,
};
use crate::folder_locks::{
    OPEN_FOLDER_MODE, READ_ONLY_FOLDER_MODE, lock_server_folder,
    set_folder_mode,
};
use crate::hosted_files::{
    hosted_server_directory, hosted_server_record, is_named_refusal,
    is_port_free, list_left_server_files,
};
use crate::support::hosting_steps::read_status;
use crate::support::server_backups::{
    start_server_backup, stop_server_backup,
};

const STORAGE_PROBLEM_PREFIX: &str = "could not use the data directory: ";
const NOT_KEEPING_REFUSAL: &str = "this device keeps no app server";
const KEPT_FILE_NAME: &str = "kept.txt";

fn pair_group() -> BackupGroup {
    let group = pair_backup_device();
    let Ok(group) = group else {
        panic!("the backup device pairs with the hosting device: {group:?}");
    };
    group
}

fn count_listed_servers(group: &BackupGroup) -> Result<usize, String> {
    let device_ids = list_server_device_ids(&group.hosting.device)?;
    Ok(device_ids.len())
}

#[test]
fn test_start_server_backup_property_a_taken_port_joins_nothing() {
    let group = pair_group();
    let occupied = TcpListener::bind((Ipv4Addr::LOCALHOST, group.backup_port));
    let Ok(occupied) = occupied else {
        panic!("another program takes the backup port: {occupied:?}");
    };

    let refused = start_server_backup(&group.backup);
    let listed_while_refused = count_listed_servers(&group);
    let left_files = list_left_server_files(&group.backup);
    drop(occupied);
    let retried = start_server_backup(&group.backup);
    let listed_after_retry = count_listed_servers(&group);

    let problem = refused.err().unwrap_or_default();
    let port_text = group.backup_port.to_string();
    assert!(problem.contains(&port_text), "{problem}");
    assert_eq!(listed_while_refused, Ok(1));
    assert!(left_files.is_empty(), "{left_files:?}");
    assert!(retried.is_ok(), "{retried:?}");
    assert_eq!(listed_after_retry, Ok(2));
}

#[test]
fn test_start_server_backup_property_an_unsaved_record_leaves_the_group() {
    let group = pair_group();
    let data_directory = group.backup.data_directory.path();
    let made = fs::create_dir_all(hosted_server_directory(&group.backup));
    assert!(made.is_ok(), "{made:?}");
    let locked = set_folder_mode(data_directory, READ_ONLY_FOLDER_MODE);
    assert_eq!(locked, Ok(()));

    let refused = start_server_backup(&group.backup);
    let unlocked = set_folder_mode(data_directory, OPEN_FOLDER_MODE);
    let listed_after_refusal = count_listed_servers(&group);
    let port_was_freed = is_port_free(group.backup_port);
    let record_was_left = hosted_server_record(&group.backup).exists();
    let retried = start_server_backup(&group.backup);

    let problem = refused.err().unwrap_or_default();
    assert!(problem.starts_with(STORAGE_PROBLEM_PREFIX), "{problem}");
    assert_eq!(unlocked, Ok(()));
    assert_eq!(listed_after_refusal, Ok(1));
    assert!(port_was_freed);
    assert!(!record_was_left);
    assert!(retried.is_ok(), "{retried:?}");
    assert_eq!(count_listed_servers(&group), Ok(2));
}

#[test]
fn test_stop_server_backup_property_a_refused_removal_records_no_server() {
    let group = pair_group();
    let started = start_server_backup(&group.backup);
    assert!(started.is_ok(), "{started:?}");
    let locked_folder = lock_server_folder(&group.backup, KEPT_FILE_NAME);
    let Ok(locked_folder) = locked_folder else {
        panic!("the standby server folder is locked: {locked_folder:?}");
    };

    let refused = stop_server_backup(&group.backup);
    let unlocked = set_folder_mode(&locked_folder, OPEN_FOLDER_MODE);
    let record_was_left = hosted_server_record(&group.backup).exists();
    let listed_after_refusal = count_listed_servers(&group);
    let restarted = group.backup.stop_and_start_again();

    let problem = refused.err().unwrap_or_default();
    assert!(is_named_refusal(&problem), "{problem}");
    assert_eq!(unlocked, Ok(()));
    assert!(!record_was_left);
    assert_eq!(listed_after_refusal, Ok(1));
    let Ok(restarted) = restarted else {
        panic!("the backup device starts again: {restarted:?}");
    };
    let status = read_status(&restarted);
    let hosted_address =
        status.map(|status| status["hosted_server_address"].clone());
    assert_eq!(hosted_address, Ok(Value::Null));
    assert!(is_port_free(group.backup_port));
    let stopped_again = stop_server_backup(&restarted);
    assert_eq!(stopped_again, Err(NOT_KEEPING_REFUSAL.to_owned()));
}

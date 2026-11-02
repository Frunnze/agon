use std::fs;
use std::path::Path;

use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::command_builders::{PreparedWorkspace, prepare_workspace};
use crate::support::pairing_steps::pair_into_workspace;
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const RECORD_FILE_NAMES: [&str; 4] = [
    "account.json",
    "app-server.json",
    "pending-join.json",
    "peer-secret.key",
];
const IDENTITY_FILE_NAME: &str = "device-identity.key";
const SERVER_FILE_NAME: &str = "app-server.json";
const BLOCKING_FILE_NAME: &str = "keeps-the-directory-full";
const NOT_FORGOTTEN_PREFIX: &str =
    "could not delete the device identity, nothing was forgotten";
const NOT_PAIRED_PROBLEM: &str =
    "the app server answered 401: the device is not paired";
const REVOKED_PROBLEM: &str =
    "the app server answered 403: the device has been revoked";
const LONGEST_STORED_FILE: usize = 64;
const FORGETTING_CASES: u32 = 12;

type StoredFile = Option<Vec<u8>>;

fn stored_file_strategy() -> impl Strategy<Value = StoredFile> {
    option::of(vec(any::<u8>(), 0..LONGEST_STORED_FILE))
}

fn stored_records_strategy() -> impl Strategy<Value = Vec<StoredFile>> {
    vec(stored_file_strategy(), RECORD_FILE_NAMES.len())
}

fn forget(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "forget_this_device" }))
}

fn read_status(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "status" }))
}

fn write_records(
    data_directory: &Path,
    records: &[StoredFile],
) -> Result<(), TestCaseError> {
    for (file_name, record) in RECORD_FILE_NAMES.iter().zip(records) {
        if let Some(contents) = record {
            fs::write(data_directory.join(file_name), contents)
                .map_err(fail)?;
        }
    }
    Ok(())
}

fn read_records(
    data_directory: &Path,
) -> Result<Vec<StoredFile>, TestCaseError> {
    let mut records = Vec::new();
    for file_name in RECORD_FILE_NAMES {
        let path = data_directory.join(file_name);
        let record = if path.exists() {
            Some(fs::read(path).map_err(fail)?)
        } else {
            None
        };
        records.push(record);
    }
    Ok(records)
}

fn block_identity_file(data_directory: &Path) -> Result<(), TestCaseError> {
    let identity_path = data_directory.join(IDENTITY_FILE_NAME);
    fs::create_dir(&identity_path).map_err(fail)?;
    fs::write(identity_path.join(BLOCKING_FILE_NAME), BLOCKING_FILE_NAME)
        .map_err(fail)
}

fn assert_new_device(status: &Value) {
    assert_eq!(status["account"], Value::Null);
    assert_eq!(status["device_id"], Value::Null);
    assert_eq!(status["server_address"], Value::Null);
    assert_eq!(status["pending_join"], Value::Null);
}

fn revoke(
    prepared: &PreparedWorkspace,
    device_id: &str,
) -> Result<(), String> {
    let command =
        json!({ "command": "revoke_device", "device_id": device_id });
    prepared.device.run(&command).map(|_| ())
}

#[test]
fn a_revoked_device_is_forgotten_and_joins_again() {
    let Ok(prepared) = prepare_workspace() else {
        panic!("the workspace is prepared");
    };
    let Ok(joining_device) = TestDevice::start() else {
        panic!("the joining device starts");
    };
    let Ok(first_device_id) = pair_into_workspace(&prepared, &joining_device)
    else {
        panic!("the device joins the workspace");
    };
    let Ok(()) = revoke(&prepared, &first_device_id) else {
        panic!("the trusted device revokes the joined device");
    };

    let refused = read_status(&joining_device);
    let forgotten = forget(&joining_device);
    let fresh_status = read_status(&joining_device);
    let second_device_id = pair_into_workspace(&prepared, &joining_device);

    assert_eq!(refused.err().as_deref(), Some(REVOKED_PROBLEM));
    assert_eq!(forgotten, Ok(Value::Null));
    let Ok(fresh_status) = fresh_status else {
        panic!("status answers after forgetting: {fresh_status:?}");
    };
    assert_new_device(&fresh_status);
    let Ok(second_device_id) = second_device_id else {
        panic!("the forgotten device joins again: {second_device_id:?}");
    };
    assert_ne!(second_device_id, first_device_id);
}

#[test]
fn a_device_of_a_reset_server_is_forgotten_and_creates_an_account() {
    let (Ok(first_server), Ok(reset_server)) =
        (TestServer::start(), TestServer::start())
    else {
        panic!("the servers start");
    };
    let Ok(mut device) = TestDevice::start() else {
        panic!("the device starts");
    };
    let Ok(_) = device.create_account(&first_server, "acme") else {
        panic!("the account is created");
    };
    let server_record = json!({ "server_address": reset_server.address });
    let server_path = device.data_directory.path().join(SERVER_FILE_NAME);
    let Ok(()) = fs::write(server_path, server_record.to_string()) else {
        panic!("the server record is replaced");
    };
    let Ok(()) = device.restart() else {
        panic!("the device restarts");
    };

    let refused = read_status(&device);
    let forgotten = forget(&device);
    let fresh_status = read_status(&device);
    let created = device.create_account(&reset_server, "acme");

    assert_eq!(refused.err().as_deref(), Some(NOT_PAIRED_PROBLEM));
    assert_eq!(forgotten, Ok(Value::Null));
    let Ok(fresh_status) = fresh_status else {
        panic!("status answers after forgetting: {fresh_status:?}");
    };
    assert_new_device(&fresh_status);
    assert!(created.is_ok(), "{created:?}");
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FORGETTING_CASES))]

    #[test]
    fn test_forget_this_device_property_no_device_file_is_left(
        records in stored_records_strategy(),
        identity in stored_file_strategy(),
    ) {
        let device = TestDevice::start().map_err(fail)?;
        let data_directory = device.data_directory.path();
        write_records(data_directory, &records)?;
        if let Some(contents) = identity {
            fs::write(data_directory.join(IDENTITY_FILE_NAME), contents)
                .map_err(fail)?;
        }

        let forgotten = forget(&device).map_err(fail)?;

        prop_assert_eq!(forgotten, Value::Null);
        prop_assert!(!data_directory.join(IDENTITY_FILE_NAME).exists());
        let left_records = read_records(data_directory)?;
        prop_assert!(left_records.iter().all(Option::is_none));
    }

    #[test]
    fn test_forget_this_device_property_a_kept_identity_keeps_every_file(
        records in stored_records_strategy(),
    ) {
        let device = TestDevice::start().map_err(fail)?;
        let data_directory = device.data_directory.path();
        write_records(data_directory, &records)?;
        block_identity_file(data_directory)?;
        let records_before = read_records(data_directory)?;

        let forgotten = forget(&device);

        let problem = forgotten.err().unwrap_or_default();
        prop_assert!(problem.starts_with(NOT_FORGOTTEN_PREFIX), "{}", problem);
        prop_assert_eq!(read_records(data_directory)?, records_before);
    }
}

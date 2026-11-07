use std::fs;

use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::hosted_files::{
    hosted_server_directory, hosted_server_record, is_port_free,
    list_left_server_files,
};
use crate::support::hosting_steps::{
    pick_free_port, read_status, start_hosting_device,
};
use crate::support::test_device::{TestDevice, fail};

const FORGET_CASES: u32 = 4;
const LONGEST_LEFTOVER: usize = 32;

type LeftoverFile = (String, String, Vec<u8>);

fn leftover_file_strategy() -> impl Strategy<Value = LeftoverFile> {
    (
        "[a-z]{1,8}",
        "[a-z]{1,8}\\.[a-z]{1,4}",
        vec(any::<u8>(), 0..LONGEST_LEFTOVER),
    )
}

fn forget(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "forget_this_device" }))
}

fn write_leftovers(
    device: &TestDevice,
    leftover_files: &[LeftoverFile],
) -> Result<(), TestCaseError> {
    let server_directory = hosted_server_directory(device);
    for (folder_name, file_name, contents) in leftover_files {
        let folder = server_directory.join(folder_name);
        fs::create_dir_all(&folder).map_err(fail)?;
        fs::write(folder.join(file_name), contents).map_err(fail)?;
    }
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FORGET_CASES))]

    #[test]
    fn test_forget_hosted_app_server_property_every_hosted_file_goes(
        leftover_files in vec(leftover_file_strategy(), 0..4),
    ) {
        let hosting = start_hosting_device().map_err(fail)?;
        write_leftovers(&hosting.device, &leftover_files)?;

        let forgotten = forget(&hosting.device);

        prop_assert_eq!(forgotten, Ok(Value::Null));
        let left_files = list_left_server_files(&hosting.device);
        prop_assert!(left_files.is_empty(), "{:?}", left_files);
        prop_assert!(is_port_free(hosting.port));
    }

    #[test]
    fn test_forget_hosted_app_server_property_partial_leftovers_go(
        leftover_files in option::of(vec(leftover_file_strategy(), 0..3)),
        record_contents in option::of(vec(any::<u8>(), 0..LONGEST_LEFTOVER)),
    ) {
        let port = pick_free_port().map_err(fail)?;
        let device = TestDevice::start_hosting_on(port).map_err(fail)?;
        if let Some(leftover_files) = &leftover_files {
            fs::create_dir_all(hosted_server_directory(&device))
                .map_err(fail)?;
            write_leftovers(&device, leftover_files)?;
        }
        if let Some(record_contents) = &record_contents {
            fs::write(hosted_server_record(&device), record_contents)
                .map_err(fail)?;
        }

        let forgotten = forget(&device);

        prop_assert_eq!(forgotten, Ok(Value::Null));
        let left_files = list_left_server_files(&device);
        prop_assert!(left_files.is_empty(), "{:?}", left_files);
    }
}

#[test]
fn test_forget_hosted_app_server_property_a_restart_after_it_hosts_nothing() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };
    let forgotten = forget(&hosting.device);
    assert_eq!(forgotten, Ok(Value::Null));

    let restarted = hosting.device.stop_and_start_again();

    let Ok(restarted) = restarted else {
        panic!("the forgotten device starts again: {restarted:?}");
    };
    let status = read_status(&restarted);
    let Ok(status) = status else {
        panic!("the status answers: {status:?}");
    };
    assert_eq!(status["hosted_server_address"], Value::Null);
    assert_eq!(status["account"], Value::Null);
    assert!(is_port_free(hosting.port));
    let left_files = list_left_server_files(&restarted);
    assert!(left_files.is_empty(), "{left_files:?}");
}

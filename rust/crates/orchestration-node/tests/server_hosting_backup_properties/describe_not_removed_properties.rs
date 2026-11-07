use std::fs;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::folder_locks::{
    OPEN_FOLDER_MODE, lock_server_folder, set_folder_mode,
};
use crate::hosted_files::{
    hosted_server_record, is_named_refusal, list_left_server_files,
};
use crate::support::hosting_steps::{pick_free_port, start_hosting_device};
use crate::support::test_device::{TestDevice, fail};

const REFUSAL_CASES: u32 = 4;
const KEPT_FILE_NAME: &str = "kept.txt";

fn forget(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "forget_this_device" }))
}

fn file_name_strategy() -> impl Strategy<Value = String> {
    "[a-z]{1,10}(\\.[a-z]{1,4})?"
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REFUSAL_CASES))]

    #[test]
    fn test_describe_not_removed_property_the_refusal_names_the_server(
        file_name in file_name_strategy(),
    ) {
        let port = pick_free_port().map_err(fail)?;
        let device = TestDevice::start_hosting_on(port).map_err(fail)?;
        let locked_folder =
            lock_server_folder(&device, &file_name).map_err(fail)?;

        let forgotten = forget(&device);
        set_folder_mode(&locked_folder, OPEN_FOLDER_MODE).map_err(fail)?;

        let problem = forgotten.err().unwrap_or_default();
        prop_assert!(is_named_refusal(&problem), "{}", problem);
        prop_assert!(!problem.contains('\n'), "{}", problem);
    }

    #[test]
    fn test_describe_not_removed_property_an_unremovable_record_is_named(
        file_name in file_name_strategy(),
    ) {
        let port = pick_free_port().map_err(fail)?;
        let device = TestDevice::start_hosting_on(port).map_err(fail)?;
        let record_path = hosted_server_record(&device);
        fs::create_dir_all(&record_path).map_err(fail)?;
        fs::write(record_path.join(&file_name), &file_name).map_err(fail)?;

        let refused = forget(&device);
        fs::remove_dir_all(&record_path).map_err(fail)?;
        let retried = forget(&device);

        let problem = refused.err().unwrap_or_default();
        prop_assert!(is_named_refusal(&problem), "{}", problem);
        prop_assert_eq!(retried, Ok(Value::Null));
        let left_files = list_left_server_files(&device);
        prop_assert!(left_files.is_empty(), "{:?}", left_files);
    }
}

#[test]
fn test_describe_not_removed_property_a_retry_after_it_removes_everything() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };
    let locked_folder = lock_server_folder(&hosting.device, KEPT_FILE_NAME);
    let Ok(locked_folder) = locked_folder else {
        panic!("the server folder is locked: {locked_folder:?}");
    };

    let refused = forget(&hosting.device);
    let unlocked = set_folder_mode(&locked_folder, OPEN_FOLDER_MODE);
    let retried = forget(&hosting.device);

    let problem = refused.err().unwrap_or_default();
    assert!(is_named_refusal(&problem), "{problem}");
    assert_eq!(unlocked, Ok(()));
    assert_eq!(retried, Ok(Value::Null));
    let left_files = list_left_server_files(&hosting.device);
    assert!(left_files.is_empty(), "{left_files:?}");
}

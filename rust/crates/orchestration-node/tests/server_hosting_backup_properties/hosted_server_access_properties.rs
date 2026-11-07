use std::fs;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::hosted_files::{
    hosted_server_directory, loopback_address, read_app_server_record,
    read_hosted_setup_code, write_hosted_record,
};
use crate::support::hosting_steps::{
    create_hosted_account, pick_free_port, read_hosted_address,
    read_server_identity, read_status, start_hosting_device,
};
use crate::support::test_device::{TestDevice, fail, read_text};

const ACCESS_CASES: u32 = 3;
const SETUP_CODE_FILE_NAME: &str = "setup-code";
const SERVER_HAS_ACCOUNT: &str =
    "the app server on this device already has an account";
const FORGOTTEN_ACCOUNT_FILES: [&str; 4] = [
    "account.json",
    "device-identity.key",
    "app-server.json",
    "server-group.json",
];

fn start_unclaimed_hosted_server() -> Result<TestDevice, String> {
    let port = pick_free_port()?;
    let device = TestDevice::start_hosting_on(port)?;
    write_hosted_record(&device, port)?;
    device.stop_and_start_again()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ACCESS_CASES))]

    #[test]
    fn test_hosted_server_access_property_the_account_uses_the_loopback(
        restart_count in 0_usize..2,
    ) {
        let hosting = start_hosting_device().map_err(fail)?;
        let mut device = hosting.device;
        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
        }

        let app_server_record = read_app_server_record(&device);
        let status = read_status(&device).map_err(fail)?;

        let app_server_record = app_server_record.map_err(fail)?;
        let recorded_address =
            read_text(&app_server_record, "/server_address");
        prop_assert_eq!(recorded_address, Ok(loopback_address(hosting.port)));
        prop_assert_eq!(&status["server_reachable"], &json!(true));
    }

    #[test]
    fn test_hosted_server_access_property_the_setup_code_stays_inside(
        restart_count in 0_usize..2,
    ) {
        let mut device = start_unclaimed_hosted_server().map_err(fail)?;
        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
        }
        let setup_code = read_hosted_setup_code(&device).map_err(fail)?;

        let created = create_hosted_account(&device).map_err(fail)?;
        let status = read_status(&device).map_err(fail)?;
        let code_path =
            hosted_server_directory(&device).join(SETUP_CODE_FILE_NAME);

        prop_assert!(!setup_code.is_empty());
        prop_assert!(!created.to_string().contains(&setup_code));
        prop_assert!(!status.to_string().contains(&setup_code));
        prop_assert!(!code_path.exists());
    }
}

#[test]
fn test_hosted_server_access_property_a_used_setup_code_refuses_an_account() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };
    let address_before = read_hosted_address(&hosting.device);
    let data_directory = hosting.device.data_directory.path();
    for file_name in FORGOTTEN_ACCOUNT_FILES {
        let removed = fs::remove_file(data_directory.join(file_name));
        assert!(removed.is_ok(), "{file_name}: {removed:?}");
    }
    let Ok(device) = hosting.device.stop_and_start_again() else {
        panic!("the device starts without its account");
    };

    let refused = create_hosted_account(&device);
    let status = read_status(&device);
    let address_after = read_hosted_address(&device);

    assert_eq!(refused, Err(SERVER_HAS_ACCOUNT.to_owned()));
    let Ok(status) = status else {
        panic!("the status answers: {status:?}");
    };
    assert_eq!(status["account"], Value::Null);
    assert_eq!(
        read_server_identity(address_after),
        read_server_identity(address_before)
    );
}

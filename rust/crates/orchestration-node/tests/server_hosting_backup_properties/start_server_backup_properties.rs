use proptest::prelude::*;
use proptest::sample::select;
use serde_json::Value;

use crate::backup_fixtures::{
    STEADY_TAKEOVER_SECONDS, list_server_device_ids, read_own_standing,
};
use crate::hosted_files::{
    is_port_free, list_left_server_files, loopback_address, read_record_port,
};
use crate::support::hosting_steps::{pick_free_port, start_hosting_device};
use crate::support::server_access::check_health_at;
use crate::support::server_backups::start_server_backup;
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const REFUSAL_CASES: u32 = 4;
const DEVICE_ROLES: [&str; 3] = ["client", "runner", "client_and_runner"];
const RUNNER_ROLE: &str = "runner";
const WORKSPACE_NAME: &str = "acme";
const RUNNER_REFUSAL: &str =
    "only a client device can keep a backup of the app server";
const NO_BACKUPS_REFUSAL: &str = "the app server keeps no backups";
const ALREADY_KEEPING_REFUSAL: &str =
    "this device already keeps the app server";
const NO_ACCOUNT_REFUSAL: &str = "this device has no account yet";
const ACTIVE_STANDING: &str = "active";

fn expected_standalone_refusal(role: &str) -> &'static str {
    if role == RUNNER_ROLE {
        return RUNNER_REFUSAL;
    }
    NO_BACKUPS_REFUSAL
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REFUSAL_CASES))]

    #[test]
    fn test_start_server_backup_property_a_standalone_server_is_refused(
        role in select(DEVICE_ROLES.to_vec()),
        attempt_count in 1_usize..3,
    ) {
        let server = TestServer::start().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let device = TestDevice::start_keeping(port, STEADY_TAKEOVER_SECONDS)
            .map_err(fail)?;
        device
            .create_account_with_role(&server, WORKSPACE_NAME, role)
            .map_err(fail)?;

        for _ in 0..attempt_count {
            let refused = start_server_backup(&device);
            let expected = expected_standalone_refusal(role).to_owned();
            prop_assert_eq!(refused, Err(expected));
        }

        let left_files = list_left_server_files(&device);
        prop_assert!(left_files.is_empty(), "{:?}", left_files);
        prop_assert!(is_port_free(port));
    }

    #[test]
    fn test_start_server_backup_property_no_account_is_refused(
        attempt_count in 1_usize..3,
    ) {
        let port = pick_free_port().map_err(fail)?;
        let device = TestDevice::start_keeping(port, STEADY_TAKEOVER_SECONDS)
            .map_err(fail)?;

        for _ in 0..attempt_count {
            let refused = start_server_backup(&device);
            prop_assert_eq!(refused, Err(NO_ACCOUNT_REFUSAL.to_owned()));
        }

        let left_files = list_left_server_files(&device);
        prop_assert!(left_files.is_empty(), "{:?}", left_files);
        prop_assert!(is_port_free(port));
    }
}

#[test]
fn test_start_server_backup_property_the_hosting_device_is_refused() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };

    let refused = start_server_backup(&hosting.device);
    let refused_again = start_server_backup(&hosting.device);
    let health = check_health_at(&loopback_address(hosting.port));
    let listed = list_server_device_ids(&hosting.device);
    let standing = read_own_standing(&hosting.device);

    assert_eq!(refused, Err(ALREADY_KEEPING_REFUSAL.to_owned()));
    assert_eq!(refused_again, refused);
    assert_eq!(health, Ok(()));
    assert_eq!(listed.map(|device_ids| device_ids.len()), Ok(1));
    assert_eq!(standing, Ok(Value::from(ACTIVE_STANDING)));
    assert_eq!(read_record_port(&hosting.device), Ok(hosting.port));
}

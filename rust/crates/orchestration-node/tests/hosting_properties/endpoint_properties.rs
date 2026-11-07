use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;

use orchestration_node::server_address::ServerAddress;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::hosting_desk::{
    heavy_cases, host_a_server, hosting_configuration,
    read_hosted_peer_address, shared_hosting, stop_and_keep_data,
    use_server_within,
};
use crate::start_problem_reading::read_hosting_problem_after_start;
use crate::support::hosting_steps::{HostingDevice, hosted_server_files};
use crate::support::test_device::{TestDevice, fail};

const PEER_SECRET_FILE_NAME: &str = "peer-secret.key";
const PEER_SECRET_LENGTH: usize = 32;
const OWNER_ONLY_MODE: u32 = 0o600;
const PERMISSION_BITS: u32 = 0o777;
const DAMAGED_SECRET_TEXT: &str = "damaged";

fn find_peer_secret(device: &TestDevice) -> PathBuf {
    let [server_directory, _record] = hosted_server_files(device);
    server_directory.join(PEER_SECRET_FILE_NAME)
}

fn restart(device: TestDevice) -> Result<TestDevice, TestCaseError> {
    device.stop_and_start_again().map_err(fail)
}

fn damaged_secret_strategy() -> impl Strategy<Value = Vec<u8>> {
    prop_oneof![
        vec(any::<u8>(), 0..PEER_SECRET_LENGTH),
        vec(any::<u8>(), PEER_SECRET_LENGTH + 1..PEER_SECRET_LENGTH * 3),
    ]
}

proptest! {
    #![proptest_config(heavy_cases(2))]

    #[test]
    fn test_bind_hosted_endpoint_property_the_peer_link_answers_health(
        request_count in 1_usize..5,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;

        let answered = use_server_within(
            &ServerAddress::Peer(peer_address),
            async |server| {
                for _ in 0..request_count {
                    server.check_health().await?;
                }
                Ok(())
            },
        );

        prop_assert_eq!(answered, Ok(()));
    }

    #[test]
    fn test_bind_hosted_endpoint_property_a_disabled_relay_publishes_no_relay(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;

        prop_assert_eq!(&peer_address.relay_url, &None);
        prop_assert!(!peer_address.direct_addresses.is_empty());
        for direct_address in &peer_address.direct_addresses {
            prop_assert_ne!(direct_address.port(), 0);
        }
    }

    #[test]
    fn test_bind_hosted_endpoint_property_restarts_keep_the_peer_key(
        restart_count in 1_usize..3,
    ) {
        let HostingDevice { mut device, .. } = host_a_server().map_err(fail)?;
        let first = read_hosted_peer_address(&device).map_err(fail)?;

        for _ in 0..restart_count {
            device = restart(device)?;
            let again = read_hosted_peer_address(&device).map_err(fail)?;
            prop_assert_eq!(
                again.endpoint_public_key,
                first.endpoint_public_key
            );
        }
    }

    #[test]
    fn test_find_or_create_server_secret_property_writes_an_owner_only_secret(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let secret_path = find_peer_secret(&hosting.device);

        let secret_bytes = fs::read(&secret_path).map_err(fail)?;
        let metadata = fs::metadata(&secret_path).map_err(fail)?;

        prop_assert_eq!(secret_bytes.len(), PEER_SECRET_LENGTH);
        let mode = metadata.permissions().mode() & PERMISSION_BITS;
        prop_assert_eq!(mode, OWNER_ONLY_MODE);
    }

    #[test]
    fn test_find_or_create_server_secret_property_restarts_keep_the_secret(
        restart_count in 1_usize..3,
    ) {
        let HostingDevice { mut device, .. } = host_a_server().map_err(fail)?;
        let first_secret = fs::read(find_peer_secret(&device)).map_err(fail)?;

        for _ in 0..restart_count {
            device = restart(device)?;
            let secret = fs::read(find_peer_secret(&device)).map_err(fail)?;
            prop_assert_eq!(&secret, &first_secret);
        }
    }

    #[test]
    fn test_find_or_create_server_secret_property_never_replaces_damage(
        damaged_secret in damaged_secret_strategy(),
    ) {
        let HostingDevice { device, port, .. } =
            host_a_server().map_err(fail)?;
        let secret_path = find_peer_secret(&device);
        let data_directory = stop_and_keep_data(device);
        fs::write(&secret_path, &damaged_secret).map_err(fail)?;

        let configuration = hosting_configuration(data_directory.path(), port);
        let started = read_hosting_problem_after_start(&configuration);
        let secret_after = fs::read(&secret_path).map_err(fail)?;

        let Ok(problem) = started else {
            return Err(fail("a damaged server key was accepted"));
        };
        prop_assert!(problem.contains(DAMAGED_SECRET_TEXT), "{problem}");
        prop_assert_eq!(&secret_after, &damaged_secret);
    }
}

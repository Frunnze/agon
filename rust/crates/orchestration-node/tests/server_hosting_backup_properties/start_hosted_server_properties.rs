use std::fs;
use std::net::{Ipv4Addr, TcpListener};
use std::os::unix::fs::PermissionsExt;

use proptest::prelude::*;
use tempfile::TempDir;

use crate::hosted_files::{hosted_server_directory, is_port_free};
use crate::runtime_steps::{
    host_on, hosted_directory_in, hosted_record_in, read_hosted_address_on,
    start_runtime,
};
use crate::support::hosting_steps::{
    pick_free_port, read_hosted_address, read_server_identity,
    start_hosting_device,
};
use crate::support::test_device::fail;

const START_CASES: u32 = 3;
const PRIVATE_FILE_MODE: u32 = 0o600;
const PERMISSION_BITS: u32 = 0o777;
const PEER_SECRET_FILE_NAME: &str = "peer-secret.key";
const SERVER_IDENTITY_FILE_NAME: &str = "server-identity.key";
const SECRET_FILE_NAMES: [&str; 2] =
    [PEER_SECRET_FILE_NAME, SERVER_IDENTITY_FILE_NAME];

proptest! {
    #![proptest_config(ProptestConfig::with_cases(START_CASES))]

    #[test]
    fn test_start_hosted_server_property_the_identity_survives_restarts(
        restart_count in 1_usize..3,
    ) {
        let hosting = start_hosting_device().map_err(fail)?;
        let address_before = read_hosted_address(&hosting.device);
        let server_directory = hosted_server_directory(&hosting.device);
        let secret_path = server_directory.join(PEER_SECRET_FILE_NAME);
        let secret_before = fs::read(&secret_path).map_err(fail)?;
        let mut device = hosting.device;

        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
            let address_after = read_hosted_address(&device);
            prop_assert_eq!(
                read_server_identity(address_after),
                read_server_identity(address_before.clone())
            );
            prop_assert!(!is_port_free(hosting.port));
        }

        prop_assert_eq!(fs::read(&secret_path).map_err(fail)?, secret_before);
    }

    #[test]
    fn test_start_hosted_server_property_a_taken_port_creates_no_folder(
        record_text_padding in "[ \n]{0,3}",
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let record_text = format!("{{\"port\":{port}}}{record_text_padding}");
        let record_path = hosted_record_in(data_directory.path());
        fs::write(&record_path, &record_text).map_err(fail)?;
        let occupied =
            TcpListener::bind((Ipv4Addr::LOCALHOST, port)).map_err(fail)?;

        let started = start_runtime(data_directory.path(), port);

        prop_assert!(started.is_ok(), "{:?}", started.err());
        let server_directory = hosted_directory_in(data_directory.path());
        prop_assert!(!server_directory.exists());
        let record_after = fs::read_to_string(&record_path).ok();
        prop_assert_eq!(record_after, Some(record_text));
        drop(occupied);
    }
}

#[test]
fn test_start_hosted_server_property_the_server_secrets_are_private() {
    let data_directory = TempDir::new();
    let Ok(data_directory) = data_directory else {
        panic!("the data directory is made: {data_directory:?}");
    };
    let Ok(port) = pick_free_port() else {
        panic!("a free port is found");
    };
    let Ok(runtime) = start_runtime(data_directory.path(), port) else {
        panic!("the node starts");
    };
    let hosted = host_on(&runtime);
    assert!(hosted.is_ok(), "{hosted:?}");
    assert!(read_hosted_address_on(&runtime).is_ok());

    let server_directory = hosted_directory_in(data_directory.path());
    for file_name in SECRET_FILE_NAMES {
        let metadata = fs::metadata(server_directory.join(file_name));
        let Ok(metadata) = metadata else {
            panic!("{file_name} exists: {metadata:?}");
        };
        let mode = metadata.permissions().mode() & PERMISSION_BITS;
        assert_eq!(mode, PRIVATE_FILE_MODE, "{file_name}");
    }
}

use std::fs;

use orchestration_node::node_runtime::NodeRuntime;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::backup_group::{STEADY_TAKEOVER_SECONDS, start_backup_group};
use crate::hosting_desk::{
    heavy_cases, host_a_server, hosting_configuration,
    read_hosted_peer_address, read_loopback_health, start_node_with,
    stop_and_keep_data,
};
use crate::restart_support::{
    check_health_at, read_hosted_ipv4_port, read_ipv4_peer_port,
    restart_keeping_the_port_free, restart_with_the_port_taken,
};
use crate::support::hosting_steps::{
    HEALTHY_ANSWER_START, HostingDevice, hosted_server_files,
};
use crate::support::test_device::{fail, read_success};

const PEER_PORT_FILE_NAME: &str = "peer-port.json";
const LARGEST_PORT: u32 = 65_535;

fn hosts_a_server(runtime: &NodeRuntime) -> Result<bool, TestCaseError> {
    let status_command = json!({ "command": "status" }).to_string();
    let reply_text = runtime.handle_command(&status_command);
    let reply: Value = serde_json::from_str(&reply_text).map_err(fail)?;
    let status = read_success(&reply).map_err(fail)?;
    Ok(!status["hosted_server_address"].is_null())
}

fn damaged_port_record_strategy() -> impl Strategy<Value = String> {
    let too_large = (LARGEST_PORT + 1..u32::MAX)
        .prop_map(|port| format!("{{\"port\": {port}}}"));
    let negative = (1_u32..LARGEST_PORT)
        .prop_map(|port| format!("{{\"port\": -{port}}}"));
    let plain_text = "[a-z ]{0,12}";
    let quoted_port = "\\{\"port\": \"[0-9]{1,5}\"\\}";
    prop_oneof![plain_text, quoted_port, too_large, negative]
}

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_bind_on_remembered_port_property_restarts_keep_the_ipv4_port(
        restart_count in 1_usize..3,
    ) {
        let HostingDevice { mut device, .. } = host_a_server().map_err(fail)?;
        let first_port = read_hosted_ipv4_port(&device).map_err(fail)?;

        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
            let again_port = read_hosted_ipv4_port(&device).map_err(fail)?;
            prop_assert_eq!(again_port, first_port);
        }
    }

    #[test]
    fn test_bind_on_remembered_port_property_a_moved_port_is_kept_next_time(
        restart_count in 1_usize..3,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let moved =
            restart_with_the_port_taken(hosting.device).map_err(fail)?;
        let old_port = read_ipv4_peer_port(&moved.old_address).map_err(fail)?;
        let moved_port = read_hosted_ipv4_port(&moved.device).map_err(fail)?;
        drop(moved.taken_port);

        prop_assert_ne!(moved_port, old_port);
        let mut device = moved.device;
        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
            let again_port = read_hosted_ipv4_port(&device).map_err(fail)?;
            prop_assert_eq!(again_port, moved_port);
        }
    }

    #[test]
    fn test_bind_on_remembered_port_property_a_damaged_record_is_refused(
        damaged_record in damaged_port_record_strategy(),
    ) {
        let HostingDevice { device, port, .. } =
            host_a_server().map_err(fail)?;
        let [server_directory, _record] = hosted_server_files(&device);
        let record_path = server_directory.join(PEER_PORT_FILE_NAME);
        let data_directory = stop_and_keep_data(device);
        fs::write(&record_path, &damaged_record).map_err(fail)?;

        let configuration = hosting_configuration(data_directory.path(), port);
        let started = start_node_with(&configuration);
        let is_hosting = match &started {
            Ok(runtime) => hosts_a_server(runtime)?,
            Err(_) => false,
        };
        let record_after = fs::read_to_string(&record_path).map_err(fail)?;

        prop_assert!(!is_hosting, "a damaged port record was used");
        prop_assert_eq!(&record_after, &damaged_record);
    }

    #[test]
    fn test_bind_hosted_endpoint_property_a_moved_server_still_serves(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let port = hosting.port;

        let moved =
            restart_with_the_port_taken(hosting.device).map_err(fail)?;
        let health = read_loopback_health(port).map_err(fail)?;
        let new_address =
            read_hosted_peer_address(&moved.device).map_err(fail)?;
        let answered = check_health_at(&new_address);

        prop_assert!(health.starts_with(HEALTHY_ANSWER_START), "{health}");
        prop_assert_eq!(answered, Ok(()));
        prop_assert_eq!(
            new_address.endpoint_public_key,
            moved.old_address.endpoint_public_key
        );
    }

    #[test]
    fn test_bind_hosted_endpoint_property_the_old_address_answers_a_restart(
        restart_count in 1_usize..3,
    ) {
        let HostingDevice { mut device, .. } = host_a_server().map_err(fail)?;
        let first_address =
            read_hosted_peer_address(&device).map_err(fail)?;

        for _ in 0..restart_count {
            let restarted =
                restart_keeping_the_port_free(device).map_err(fail)?;
            let answered = check_health_at(&first_address);
            prop_assert_eq!(answered, Ok(()));
            device = restarted.device;
        }
    }

    #[test]
    fn test_bind_hosted_endpoint_property_a_backup_keeps_its_port(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let first_port = read_hosted_ipv4_port(&group.backup).map_err(fail)?;

        let group = group.restart_the_backup().map_err(fail)?;
        let again_port = read_hosted_ipv4_port(&group.backup).map_err(fail)?;

        prop_assert_eq!(again_port, first_port);
    }
}

use std::thread;
use std::time::{Duration, Instant};

use orchestration_core::server_group::ServerStanding;
use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;
use serde_json::Value;

use crate::backup_group::{STEADY_TAKEOVER_SECONDS, start_backup_group};
use crate::hosting_desk::{
    heavy_cases, host_a_server, read_group_at, use_server_within,
};
use crate::restart_support::{
    WATCH_PERIOD, WATCHED_TAKEOVER_SECONDS, restart_the_active,
    restart_with_the_port_taken, retry_until_reached,
    wait_for_the_new_announcement,
};
use crate::support::server_backups::read_app_servers;
use crate::support::test_device::{TestDevice, fail};

const QUICK_ANSWER_LIMIT: Duration = Duration::from_secs(5);
const NO_FRESH_COPY: &str = "the active server did not describe the copies";

fn read_fresh_app_servers(device: &TestDevice) -> Result<Value, String> {
    let app_servers = read_app_servers(device)?;
    let Some(servers) = app_servers["servers"].as_array() else {
        return Err(NO_FRESH_COPY.to_owned());
    };
    let has_a_fresh_copy =
        servers.iter().any(|server| server["copy"].is_object());
    if !has_a_fresh_copy {
        return Err(NO_FRESH_COPY.to_owned());
    }
    Ok(app_servers)
}

fn measure_later_requests(
    address: &ServerAddress,
    request_count: usize,
) -> Result<Vec<Duration>, String> {
    use_server_within(address, async |server| {
        server.check_health().await?;
        let mut later_waits = Vec::new();
        for _ in 0..request_count {
            let asked_at = Instant::now();
            server.check_health().await?;
            later_waits.push(asked_at.elapsed());
        }
        Ok(later_waits)
    })
}

fn send_health_checks(
    address: &ServerAddress,
    request_count: usize,
) -> Result<(), String> {
    use_server_within(address, async |server| {
        for _ in 0..request_count {
            server.check_health().await?;
        }
        Ok(())
    })
}

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_peer_link_route_deliver_property_later_requests_answer_at_once(
        request_count in 2_usize..5,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let moved =
            restart_with_the_port_taken(hosting.device).map_err(fail)?;
        wait_for_the_new_announcement(&moved).map_err(fail)?;
        let old_address = ServerAddress::Peer(moved.old_address.clone());

        let later_waits = retry_until_reached(|| {
            measure_later_requests(&old_address, request_count)
        })
        .map_err(fail)?;

        prop_assert_eq!(later_waits.len(), request_count);
        for waited in later_waits {
            prop_assert!(waited <= QUICK_ANSWER_LIMIT, "{waited:?}");
        }
    }

    #[test]
    fn test_peer_link_route_deliver_property_a_backup_follows_a_moved_active(
        write_count in 1_usize..3,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;

        let restarted =
            restart_the_active(group, restart_with_the_port_taken)
                .map_err(fail)?;

        for _ in 0..write_count {
            let name = restarted.write_a_project().map_err(fail)?;
            let copied =
                restarted.wait_until_the_backup_caught_up().map_err(fail)?;
            let copied_projects = copied["projects"].to_string();
            prop_assert!(copied_projects.contains(&name), "{copied_projects}");
        }
    }

    #[test]
    fn test_peer_link_route_deliver_property_a_moved_active_keeps_its_writes(
        write_count in 1_usize..3,
    ) {
        let group =
            start_backup_group(WATCHED_TAKEOVER_SECONDS).map_err(fail)?;
        let restarted =
            restart_the_active(group, restart_with_the_port_taken)
                .map_err(fail)?;
        let mut accepted_names = Vec::new();
        for _ in 0..write_count {
            accepted_names.push(restarted.write_a_project().map_err(fail)?);
        }

        thread::sleep(WATCH_PERIOD);
        let standing = restarted.read_active_standing().map_err(fail)?;
        let active_projects =
            restarted.read_active_projects().map_err(fail)?;
        let copied =
            restarted.wait_until_the_backup_caught_up().map_err(fail)?;

        prop_assert_eq!(standing, ServerStanding::Active);
        let copied_projects = copied["projects"].to_string();
        for name in &accepted_names {
            prop_assert!(active_projects.contains(name), "{active_projects}");
            prop_assert!(copied_projects.contains(name), "{copied_projects}");
        }
    }

    #[test]
    fn test_reuse_or_connect_property_signed_reads_reach_a_moved_server(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let moved =
            restart_with_the_port_taken(hosting.device).map_err(fail)?;
        wait_for_the_new_announcement(&moved).map_err(fail)?;

        let old_address = ServerAddress::Peer(moved.old_address.clone());

        let view =
            retry_until_reached(|| read_group_at(&moved.device, &old_address))
                .map_err(fail)?;

        prop_assert_eq!(view.standing, ServerStanding::Active);
        let listed_keys: Vec<[u8; 32]> = view
            .group
            .members
            .iter()
            .map(|member| member.address.endpoint_public_key)
            .collect();
        let expected_keys = vec![moved.old_address.endpoint_public_key];
        prop_assert_eq!(listed_keys, expected_keys);
    }

    #[test]
    fn test_reuse_or_connect_property_repeated_requests_keep_answering(
        request_count in 2_usize..6,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let moved =
            restart_with_the_port_taken(hosting.device).map_err(fail)?;
        wait_for_the_new_announcement(&moved).map_err(fail)?;
        let old_address = ServerAddress::Peer(moved.old_address.clone());

        let answered = retry_until_reached(|| {
            send_health_checks(&old_address, request_count)
        });

        prop_assert_eq!(answered, Ok(()));
    }

    #[test]
    fn test_reuse_or_connect_property_a_paired_client_reaches_a_moved_active(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let restarted =
            restart_the_active(group, restart_with_the_port_taken)
                .map_err(fail)?;
        restarted.wait_until_the_backup_caught_up().map_err(fail)?;

        let app_servers =
            retry_until_reached(|| read_fresh_app_servers(&restarted.backup));

        prop_assert!(app_servers.is_ok(), "{app_servers:?}");
    }
}

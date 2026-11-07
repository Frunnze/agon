use std::fs;
use std::net::SocketAddr;

use orchestration_core::server_group::{ServerGroup, ServerStanding};
use orchestration_node::server_address::ServerAddress;
use orchestration_security::identity::device_id_for;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::backup_group::shared_backup_group;
use crate::hosting_desk::{
    heavy_cases, host_a_server, hosting_configuration, loopback_address,
    read_group_at, read_hosted_peer_address, read_loopback_health,
    read_own_group, shared_hosting, stop_and_keep_data, use_server_within,
};
use crate::local_announcements::{
    describe_announced_address, watch_for_announcement,
};
use crate::start_problem_reading::read_hosting_problem_after_start;
use crate::support::hosting_steps::{
    HostingDevice, hosted_server_files, read_status,
};
use crate::support::server_backups::{create_project, read_hosted_state};
use crate::support::test_device::{TestDevice, fail, read_text};

const STATE_FILE_NAME: &str = "state.json";
const SERVER_FAILED_START: &str = "the app server on this device failed: ";
const MISDIRECTED_ANSWER_START: &str = "HTTP/1.1 421";
const NOT_JSON_MARK: u8 = b'#';

fn the_only_member_id(group: &ServerGroup) -> Result<String, TestCaseError> {
    let [member] = group.members.as_slice() else {
        return Err(fail(format!("the group is not alone: {group:?}")));
    };
    Ok(member.membership.server_id.0.clone())
}

fn hosted_state_path(device: &TestDevice) -> std::path::PathBuf {
    let [server_directory, _record] = hosted_server_files(device);
    server_directory.join(STATE_FILE_NAME)
}

fn unreadable_state_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..64).prop_map(|mut tail| {
        tail.insert(0, NOT_JSON_MARK);
        tail
    })
}

fn project_names_strategy() -> impl Strategy<Value = Vec<String>> {
    vec("[a-z]{3,10}", 1..4)
}

proptest! {
    #![proptest_config(heavy_cases(2))]

    #[test]
    fn test_hosted_app_server_start_property_both_routes_show_one_group(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;

        let over_loopback =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;
        let peer_route = ServerAddress::Peer(peer_address);
        let over_peer =
            read_group_at(&hosting.device, &peer_route).map_err(fail)?;

        prop_assert_eq!(&over_peer.group.term, &over_loopback.group.term);
        prop_assert_eq!(
            the_only_member_id(&over_peer.group)?,
            the_only_member_id(&over_loopback.group)?
        );
    }

    #[test]
    fn test_hosted_app_server_start_property_unreadable_state_is_kept(
        unreadable_state in unreadable_state_strategy(),
    ) {
        let HostingDevice { device, port, .. } =
            host_a_server().map_err(fail)?;
        let state_path = hosted_state_path(&device);
        let data_directory = stop_and_keep_data(device);
        fs::write(&state_path, &unreadable_state).map_err(fail)?;

        let configuration = hosting_configuration(data_directory.path(), port);
        let started = read_hosting_problem_after_start(&configuration);
        let state_after = fs::read(&state_path).map_err(fail)?;

        let Ok(problem) = started else {
            return Err(fail("an unreadable state was replaced"));
        };
        prop_assert!(problem.starts_with(SERVER_FAILED_START), "{problem}");
        prop_assert_eq!(&state_after, &unreadable_state);
    }

    #[test]
    fn test_hosted_app_server_start_property_announces_the_server(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;
        let wanted = describe_announced_address(&peer_address);

        let (_watch, announced) =
            watch_for_announcement(&wanted).map_err(fail)?;
        let view =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;

        let peer_ports: Vec<u16> = peer_address
            .direct_addresses
            .iter()
            .map(SocketAddr::port)
            .collect();
        prop_assert!(peer_ports.contains(&announced.port), "{announced:?}");
        let server_id = the_only_member_id(&view.group)?;
        let full_name = &announced.full_name;
        prop_assert!(full_name.contains(&server_id), "{announced:?}");
    }

    #[test]
    fn test_hosted_app_server_server_property_the_term_names_the_server(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        let view =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;

        let member_id = the_only_member_id(&view.group)?;
        let term = view.group.term.as_ref();
        prop_assert_eq!(term.map(|term| term.server_id.0.clone()),
            Some(member_id.clone()));
        let member = &view.group.members[0].membership;
        let key_id = device_id_for(&member.server_signing_public_key);
        prop_assert_eq!(key_id.0, member_id);
        prop_assert_eq!(view.standing, ServerStanding::Active);
    }

    #[test]
    fn test_hosted_app_server_server_property_writes_reach_the_saved_state(
        project_names in project_names_strategy(),
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let workspace_id =
            read_text(&hosting.account, "/workspaces/0/id").map_err(fail)?;

        for name in &project_names {
            create_project(&hosting.device, &workspace_id, name)
                .map_err(fail)?;
        }
        let saved = read_hosted_state(&hosting.device).map_err(fail)?;
        let listed = hosting
            .device
            .run(&json!({
                "command": "list_projects",
                "workspace_id": workspace_id,
            }))
            .map_err(fail)?;

        let saved_text = saved["projects"].to_string();
        let listed_text = listed.to_string();
        for name in &project_names {
            prop_assert!(saved_text.contains(name.as_str()), "{saved_text}");
            prop_assert!(listed_text.contains(name.as_str()), "{listed_text}");
        }
    }

    #[test]
    fn test_hosted_app_server_server_property_a_backup_refuses_requests(
        _round in 0_u8..2,
    ) {
        let group = shared_backup_group().map_err(fail)?;
        let health = read_loopback_health(group.backup_port).map_err(fail)?;
        let view = group.read_backup_group().map_err(fail)?;

        prop_assert!(health.starts_with(MISDIRECTED_ANSWER_START), "{health}");
        prop_assert_eq!(view.standing, ServerStanding::Backup);
    }

    #[test]
    fn test_hosted_app_server_endpoint_property_the_member_key_is_hosted(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;

        let view =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;

        let member = &view.group.members[0];
        prop_assert_eq!(
            member.address.endpoint_public_key,
            peer_address.endpoint_public_key
        );
        prop_assert!(member.has_signed_address());
    }

    #[test]
    fn test_hosted_app_server_endpoint_property_the_member_address_answers(
        request_count in 1_usize..3,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let view =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;
        let member_route = ServerAddress::Peer(view.group.members[0]
            .address
            .clone());

        let answered = use_server_within(&member_route, async |server| {
            for _ in 0..request_count {
                server.check_health().await?;
            }
            Ok(())
        });

        prop_assert_eq!(answered, Ok(()));
    }

    #[test]
    fn test_hosted_app_server_endpoint_property_the_backup_member_is_hosted(
        _round in 0_u8..2,
    ) {
        let group = shared_backup_group().map_err(fail)?;
        let backup_address =
            read_hosted_peer_address(&group.backup).map_err(fail)?;

        let view = group.read_active_group().map_err(fail)?;

        let backup_member = view.group.members.iter().find(|member| {
            Some(&member.membership.server_id)
                != view.group.active_server_id()
        });
        let backup_key =
            backup_member.map(|member| member.address.endpoint_public_key);
        prop_assert_eq!(backup_key, Some(backup_address.endpoint_public_key));
    }

    #[test]
    fn test_hosted_app_server_public_address_property_round_trips_as_text(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let status = read_status(&hosting.device).map_err(fail)?;
        let address_text =
            read_text(&status, "/hosted_server_address").map_err(fail)?;

        let parsed = ServerAddress::parse(&address_text).map_err(fail)?;

        prop_assert_eq!(parsed.to_string(), address_text);
        prop_assert!(matches!(parsed, ServerAddress::Peer(_)));
    }

    #[test]
    fn test_hosted_app_server_public_address_property_ends_when_forgotten(
        _round in 0_u8..2,
    ) {
        let hosting = host_a_server().map_err(fail)?;

        let forgotten = hosting
            .device
            .run(&json!({ "command": "forget_this_device" }));
        let status = read_status(&hosting.device).map_err(fail)?;

        prop_assert_eq!(forgotten, Ok(Value::Null));
        prop_assert_eq!(&status["hosted_server_address"], &Value::Null);
    }

    #[test]
    fn test_hosted_app_server_public_address_property_matches_the_member(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;

        let view = read_group_at(
            &hosting.device,
            &loopback_address(hosting.port),
        )
        .map_err(fail)?;

        let member_address = &view.group.members[0].address;
        prop_assert_eq!(&member_address.relay_url, &peer_address.relay_url);
        prop_assert_eq!(
            member_address.endpoint_public_key,
            peer_address.endpoint_public_key
        );
    }
}

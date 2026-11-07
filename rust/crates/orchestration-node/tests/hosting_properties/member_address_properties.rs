use std::thread;
use std::time::{Duration, Instant};

use orchestration_core::peer_address::PeerAddress;
use orchestration_core::server_group::{ServerGroup, ServerStanding};
use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;

use crate::backup_group::{
    BackupGroup, STEADY_TAKEOVER_SECONDS, shared_backup_group,
    start_backup_group, take_over_and_return,
};
use crate::hosting_desk::{
    heavy_cases, read_group_at, read_hosted_peer_address, read_own_group,
    use_server_within, wait_until_listed_address_is_current,
    wait_until_server_standing,
};
use crate::support::test_device::{TestDevice, fail};
use crate::support::waiting::wait_for;

const CHECK_PAUSE: Duration = Duration::from_secs(6);
const AGREEMENT_LIMIT: Duration = Duration::from_secs(40);
const RESUME_LIMIT: Duration = Duration::from_secs(30);
const MISDIRECTED_TEXT: &str = "421";

fn list_server_ids(group: &ServerGroup) -> Vec<String> {
    let mut server_ids: Vec<String> = Vec::new();
    for member in &group.members {
        server_ids.push(member.membership.server_id.0.clone());
    }
    server_ids.sort();
    server_ids
}

fn wait_until_members_agree(
    viewer: &TestDevice,
    viewer_port: u16,
    source: &TestDevice,
    source_port: u16,
) -> Result<ServerGroup, String> {
    wait_for(AGREEMENT_LIMIT, "the member lists to agree", || {
        let seen = read_own_group(viewer, viewer_port)?.group;
        let source_group = read_own_group(source, source_port)?.group;
        let is_same = seen.members == source_group.members;
        Ok(is_same.then_some(seen))
    })
}

fn restart_active_beside_a_dead_backup(
    group: BackupGroup,
) -> Result<(TestDevice, Duration), String> {
    drop(group.backup);
    let port = group.hosting.port;
    let restarted_at = Instant::now();
    let active = group.hosting.device.stop_and_start_again()?;
    wait_until_server_standing(&active, port, ServerStanding::Active)?;
    Ok((active, restarted_at.elapsed()))
}

fn find_backup_member_address(
    group: &BackupGroup,
) -> Result<PeerAddress, TestCaseError> {
    let identity = group.backup.load_identity().map_err(fail)?;
    let view = group.read_active_group().map_err(fail)?;
    let member = view.group.find_member_of_device(&identity.device_id());
    let member = member.ok_or_else(|| fail("the backup is not listed"))?;
    Ok(member.address.clone())
}

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_member_links_remember_addresses_property_lists_every_member(
        _round in 0_u8..1,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        let active_view = group.read_active_group().map_err(fail)?;
        let backup_view = group.read_backup_group().map_err(fail)?;

        prop_assert_eq!(
            list_server_ids(&backup_view.group),
            list_server_ids(&active_view.group)
        );
    }

    #[test]
    fn test_member_links_remember_addresses_property_copies_agree(
        _round in 0_u8..1,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        let agreed = wait_until_members_agree(
            &group.backup,
            group.backup_port,
            &group.hosting.device,
            group.hosting.port,
        );

        prop_assert!(agreed.is_ok(), "{agreed:?}");
    }

    #[test]
    fn test_member_links_remember_addresses_property_the_returner_agrees(
        _round in 0_u8..1,
    ) {
        let returned = take_over_and_return().map_err(fail)?;

        let agreed = wait_until_members_agree(
            &returned.returned,
            returned.returned_port,
            &returned.active,
            returned.active_port,
        );

        prop_assert!(agreed.is_ok(), "{agreed:?}");
    }

    #[test]
    fn test_member_links_probe_members_property_the_returner_meets_the_term(
        _round in 0_u8..1,
    ) {
        let returned = take_over_and_return().map_err(fail)?;

        let returned_view =
            read_own_group(&returned.returned, returned.returned_port)
                .map_err(fail)?;
        let active_view =
            read_own_group(&returned.active, returned.active_port)
                .map_err(fail)?;

        prop_assert_eq!(returned_view.standing, ServerStanding::Backup);
        prop_assert_eq!(active_view.standing, ServerStanding::Active);
    }

    #[test]
    fn test_member_links_probe_members_property_the_active_stays_active(
        check_count in 2_usize..4,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        for _ in 0..check_count {
            let view = group.read_active_group().map_err(fail)?;
            prop_assert_eq!(view.standing, ServerStanding::Active);
            thread::sleep(CHECK_PAUSE);
        }
    }

    #[test]
    fn test_member_links_probe_members_property_a_dead_backup_allows_resume(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let port = group.hosting.port;

        let (active, _waited) =
            restart_active_beside_a_dead_backup(group).map_err(fail)?;
        let view = read_own_group(&active, port).map_err(fail)?;

        prop_assert_eq!(view.standing, ServerStanding::Active);
    }

    #[test]
    fn test_member_links_send_own_member_property_lists_a_restarted_backup(
        _round in 0_u8..1,
    ) {
        let group = start_backup_group(STEADY_TAKEOVER_SECONDS)
            .map_err(fail)?
            .restart_the_backup()
            .map_err(fail)?;

        let listed = wait_until_listed_address_is_current(
            &group.backup,
            &group.hosting.device,
            group.hosting.port,
        );

        prop_assert!(listed.is_ok(), "{listed:?}");
    }

    #[test]
    fn test_member_links_send_own_member_property_keeps_the_membership(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let identity = group.backup.load_identity().map_err(fail)?;
        let before = group.read_active_group().map_err(fail)?;

        let group = group.restart_the_backup().map_err(fail)?;
        wait_until_listed_address_is_current(
            &group.backup,
            &group.hosting.device,
            group.hosting.port,
        )
        .map_err(fail)?;
        let after = group.read_active_group().map_err(fail)?;

        let device_id = identity.device_id();
        let membership_before = before
            .group
            .find_member_of_device(&device_id)
            .map(|member| member.membership.clone());
        let membership_after = after
            .group
            .find_member_of_device(&device_id)
            .map(|member| member.membership.clone());
        prop_assert!(membership_before.is_some());
        prop_assert_eq!(membership_after, membership_before);
    }

    #[test]
    fn test_member_links_send_own_member_property_the_listed_address_answers(
        _round in 0_u8..1,
    ) {
        let group = start_backup_group(STEADY_TAKEOVER_SECONDS)
            .map_err(fail)?
            .restart_the_backup()
            .map_err(fail)?;
        wait_until_listed_address_is_current(
            &group.backup,
            &group.hosting.device,
            group.hosting.port,
        )
        .map_err(fail)?;

        let address = find_backup_member_address(&group)?;
        let answered = use_server_within(
            &ServerAddress::Peer(address),
            async |server| server.check_health().await,
        );

        let Err(problem) = answered else {
            return Err(fail("a backup answered a health check as active"));
        };
        prop_assert!(problem.contains(MISDIRECTED_TEXT), "{problem}");
    }

    #[test]
    fn test_member_links_probe_property_a_dead_member_is_passed_in_time(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;

        let (_active, waited) =
            restart_active_beside_a_dead_backup(group).map_err(fail)?;

        prop_assert!(waited <= RESUME_LIMIT, "{waited:?}");
    }

    #[test]
    fn test_member_links_probe_property_signed_reads_reach_a_backup(
        _round in 0_u8..1,
    ) {
        let group = shared_backup_group().map_err(fail)?;
        let backup_address =
            read_hosted_peer_address(&group.backup).map_err(fail)?;

        let probed = read_group_at(
            &group.hosting.device,
            &ServerAddress::Peer(backup_address),
        )
        .map_err(fail)?;
        let active_view = group.read_active_group().map_err(fail)?;

        prop_assert_eq!(probed.standing, ServerStanding::Backup);
        prop_assert_eq!(&probed.group.term, &active_view.group.term);
    }

    #[test]
    fn test_member_links_probe_property_the_returner_takes_the_probed_term(
        _round in 0_u8..1,
    ) {
        let returned = take_over_and_return().map_err(fail)?;

        let returned_view =
            read_own_group(&returned.returned, returned.returned_port)
                .map_err(fail)?;
        let active_view =
            read_own_group(&returned.active, returned.active_port)
                .map_err(fail)?;

        let active_term = active_view.group.term.as_ref();
        prop_assert_eq!(active_term.map(|term| term.number), Some(2));
        prop_assert_eq!(returned_view.group.term.as_ref(), active_term);
    }
}

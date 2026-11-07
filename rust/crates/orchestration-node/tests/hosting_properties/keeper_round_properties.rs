use std::thread;
use std::time::Duration;

use orchestration_core::server_group::ServerStanding;
use proptest::prelude::*;

use crate::backup_group::{
    STEADY_TAKEOVER_SECONDS, read_state_revision, shared_backup_group,
    start_backup_group, take_over_and_return,
};
use crate::hosting_desk::{
    heavy_cases, host_a_server, loopback_address, read_group_at,
    read_loopback_health, read_own_group, shared_hosting,
};
use crate::support::server_backups::{
    create_project, read_hosted_state, wait_until_copied,
};
use crate::support::test_device::{TestDevice, fail};
use crate::support::waiting::wait_for;

const CHECK_PAUSE: Duration = Duration::from_secs(6);
const SETTLE_PAUSE: Duration = Duration::from_secs(4);
const IDLE_PERIOD: Duration = Duration::from_secs(12);
const REFUSAL_PAUSE: Duration = Duration::from_secs(10);
const MATCH_LIMIT: Duration = Duration::from_secs(30);
const MISDIRECTED_ANSWER_START: &str = "HTTP/1.1 421";
const FOLLOWED_PROJECT: &str = "written-after-the-takeover";
const SAMPLE_COUNT: usize = 10;
const SAMPLE_PAUSE: Duration = Duration::from_millis(300);

fn wait_until_view_matches_saved(
    device: &TestDevice,
    port: u16,
) -> Result<(), String> {
    wait_for(MATCH_LIMIT, "the view to match the saved group", || {
        let view = read_own_group(device, port)?;
        let saved = read_hosted_state(device)?;
        let viewed = serde_json::to_value(&view.group)
            .map_err(|problem| problem.to_string())?;
        Ok((viewed == saved["server_group"]).then_some(()))
    })
}

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_keep_group_property_keeps_following_across_writes(
        write_count in 1_usize..4,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        for _ in 0..write_count {
            let copied = group.write_and_wait_for_copy();
            prop_assert!(copied.is_ok(), "{copied:?}");
        }
    }

    #[test]
    fn test_keep_group_property_an_ended_keeper_leaves_the_server_up(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;

        group.revoke_the_backup().map_err(fail)?;
        thread::sleep(REFUSAL_PAUSE);
        let health = read_loopback_health(group.backup_port).map_err(fail)?;
        let backup_route = loopback_address(group.backup_port);
        let view = read_group_at(&group.hosting.device, &backup_route)
            .map_err(fail)?;

        prop_assert!(health.starts_with(MISDIRECTED_ANSWER_START), "{health}");
        prop_assert_eq!(view.standing, ServerStanding::Backup);
    }

    #[test]
    fn test_keep_group_property_the_copy_equals_its_source(
        project_count in 1_usize..3,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;

        for _ in 0..project_count {
            group.write_and_wait_for_copy().map_err(fail)?;
        }
        let equal = wait_for(MATCH_LIMIT, "the copy to equal its source", || {
            let source = read_hosted_state(&group.hosting.device)?;
            let copied = read_hosted_state(&group.backup)?;
            Ok((copied == source).then_some(()))
        });

        prop_assert!(equal.is_ok(), "{equal:?}");
    }

    #[test]
    fn test_run_round_property_a_lone_active_stays_active(
        check_count in 2_usize..4,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let first =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;

        for _ in 0..check_count {
            thread::sleep(CHECK_PAUSE);
            let view =
                read_own_group(&hosting.device, hosting.port).map_err(fail)?;
            prop_assert_eq!(view.standing, ServerStanding::Active);
            prop_assert_eq!(&view.group.term, &first.group.term);
        }
    }

    #[test]
    fn test_run_round_property_a_backup_stays_a_backup_beside_the_active(
        check_count in 2_usize..4,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        for _ in 0..check_count {
            let view = group.read_backup_group().map_err(fail)?;
            prop_assert_eq!(view.standing, ServerStanding::Backup);
            thread::sleep(CHECK_PAUSE);
        }
    }

    #[test]
    fn test_run_round_property_idle_rounds_write_nothing(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        thread::sleep(SETTLE_PAUSE);

        let before = read_state_revision(&hosting.device).map_err(fail)?;
        thread::sleep(IDLE_PERIOD);
        let after = read_state_revision(&hosting.device).map_err(fail)?;

        prop_assert_eq!(after, before);
    }

    #[test]
    fn test_follow_leader_property_the_returner_copies_new_writes(
        _round in 0_u8..1,
    ) {
        let returned = take_over_and_return().map_err(fail)?;

        create_project(
            &returned.active,
            &returned.workspace_id,
            FOLLOWED_PROJECT,
        )
            .map_err(fail)?;
        let copied = wait_until_copied(&returned.active, &returned.returned)
            .map_err(fail)?;

        let copied_text = copied["projects"].to_string();
        prop_assert!(copied_text.contains(FOLLOWED_PROJECT), "{copied_text}");
    }

    #[test]
    fn test_follow_leader_property_a_restart_keeps_the_copy(
        restart_count in 1_usize..3,
    ) {
        let mut group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        group.write_and_wait_for_copy().map_err(fail)?;

        for _ in 0..restart_count {
            let before = read_state_revision(&group.backup).map_err(fail)?;
            group = group.restart_the_backup().map_err(fail)?;
            let after = read_state_revision(&group.backup).map_err(fail)?;
            prop_assert!(after >= before, "{before} {after}");
        }
    }

    #[test]
    fn test_follow_leader_property_copied_projects_stay_copied(
        write_count in 1_usize..3,
    ) {
        let group = shared_backup_group().map_err(fail)?;
        let mut copied_counts: Vec<usize> = Vec::new();

        for _ in 0..write_count {
            let copied = group.write_and_wait_for_copy().map_err(fail)?;
            let projects = copied["projects"].as_object();
            let project_count = projects.map(serde_json::Map::len);
            copied_counts.push(project_count.unwrap_or_default());
        }

        for pair in copied_counts.windows(2) {
            prop_assert!(pair[0] < pair[1], "{copied_counts:?}");
        }
    }

    #[test]
    fn test_describe_group_property_matches_the_saved_group(
        _round in 0_u8..1,
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        let matched =
            wait_until_view_matches_saved(&hosting.device, hosting.port);

        prop_assert!(matched.is_ok(), "{matched:?}");
    }

    #[test]
    fn test_describe_group_property_the_backup_view_matches_its_copy(
        _round in 0_u8..1,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        let matched =
            wait_until_view_matches_saved(&group.backup, group.backup_port);

        prop_assert!(matched.is_ok(), "{matched:?}");
    }

    #[test]
    fn test_describe_group_property_revisions_never_fall(
        write_count in 1_usize..3,
    ) {
        let group = shared_backup_group().map_err(fail)?;
        let mut revisions: Vec<u64> = Vec::new();

        for _ in 0..write_count {
            group.write_and_wait_for_copy().map_err(fail)?;
            for _ in 0..SAMPLE_COUNT {
                let view = group.read_active_group().map_err(fail)?;
                revisions.push(view.revision);
                thread::sleep(SAMPLE_PAUSE);
            }
        }

        for pair in revisions.windows(2) {
            prop_assert!(pair[0] <= pair[1], "{revisions:?}");
        }
        let saved_revision =
            read_state_revision(&group.hosting.device).map_err(fail)?;
        let last = revisions.last().copied().unwrap_or_default();
        prop_assert!(saved_revision >= last, "{saved_revision} {last}");
    }
}

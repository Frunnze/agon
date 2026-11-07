use std::thread;

use orchestration_core::server_group::ServerStanding;
use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;

use crate::backup_group::{STEADY_TAKEOVER_SECONDS, start_backup_group};
use crate::hosting_desk::{heavy_cases, read_group_at};
use crate::restart_support::{
    WATCH_PERIOD, WATCHED_TAKEOVER_SECONDS, check_health_at,
    restart_keeping_the_port_free, restart_the_active,
};
use crate::support::test_device::fail;

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_keep_group_property_a_steady_backup_catches_up_after_a_restart(
        write_count in 1_usize..3,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;

        let restarted =
            restart_the_active(group, restart_keeping_the_port_free)
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
    fn test_keep_group_property_a_ready_backup_keeps_restarted_writes(
        write_count in 1_usize..3,
    ) {
        let group =
            start_backup_group(WATCHED_TAKEOVER_SECONDS).map_err(fail)?;
        let restarted =
            restart_the_active(group, restart_keeping_the_port_free)
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
    fn test_keep_group_property_clients_reach_a_restarted_active_as_before(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let restarted =
            restart_the_active(group, restart_keeping_the_port_free)
                .map_err(fail)?;
        let old_address = restarted.active.old_address.clone();

        let answered = check_health_at(&old_address);
        let view = read_group_at(
            &restarted.backup,
            &ServerAddress::Peer(old_address),
        )
        .map_err(fail)?;

        prop_assert_eq!(answered, Ok(()));
        prop_assert_eq!(view.standing, ServerStanding::Active);
    }
}

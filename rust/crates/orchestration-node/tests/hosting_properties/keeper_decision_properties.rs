use std::thread;
use std::time::{Duration, Instant};

use orchestration_core::server_group::ServerStanding;
use proptest::prelude::*;

use crate::backup_group::{
    READY_TAKEOVER_SECONDS, STEADY_TAKEOVER_SECONDS, TAKEOVER_LIMIT,
    shared_backup_group, start_and_take_over, start_backup_group,
    take_over_and_return,
};
use crate::hosting_desk::{
    heavy_cases, host_a_server, read_own_group, shared_hosting,
    wait_until_listed_address_is_current, wait_until_server_standing,
};
use crate::restart_support::restart_with_the_port_taken;
use crate::support::hosting_steps::HostingDevice;
use crate::support::server_backups::{
    create_project, read_hosted_state, wait_until_copied, wait_until_standing,
};
use crate::support::test_device::{TestDevice, fail};

const TAKEOVER_AUDIT_TEXT: &str =
    "Took over as the active app server (term 2)";
const ADDRESS_AUDIT_TEXT: &str = "Updated the address of";
const TAKEN_OVER_PROJECT: &str = "written-by-the-new-active";
const RESUMED_PROJECT: &str = "written-after-resuming";
const SETTLE_PAUSE: Duration = Duration::from_secs(4);
const IDLE_PERIOD: Duration = Duration::from_secs(12);

fn count_audit_entries(
    device: &TestDevice,
    entry_text: &str,
) -> Result<usize, TestCaseError> {
    let state = read_hosted_state(device).map_err(fail)?;
    let audit_text = state["audit_log"].to_string();
    Ok(audit_text.matches(entry_text).count())
}

fn find_device_copy(
    viewer: &TestDevice,
    viewer_port: u16,
    copier: &TestDevice,
) -> Result<bool, TestCaseError> {
    let identity = copier.load_identity().map_err(fail)?;
    let view = read_own_group(viewer, viewer_port).map_err(fail)?;
    let device_id = identity.device_id();
    Ok(view.copies.iter().any(|copy| copy.device_id == device_id))
}

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_decide_and_act_property_one_active_after_a_return(
        _round in 0_u8..1,
    ) {
        let returned = take_over_and_return().map_err(fail)?;

        let returned_view =
            read_own_group(&returned.returned, returned.returned_port)
                .map_err(fail)?;
        let active_view =
            read_own_group(&returned.active, returned.active_port)
                .map_err(fail)?;

        let standings = [returned_view.standing, active_view.standing];
        let active_count = standings
            .iter()
            .filter(|standing| **standing == ServerStanding::Active)
            .count();
        prop_assert_eq!(active_count, 1);
    }

    #[test]
    fn test_decide_and_act_property_a_restarted_active_resumes(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let port = group.hosting.port;

        let active =
            group.hosting.device.stop_and_start_again().map_err(fail)?;
        let resumed =
            wait_until_server_standing(&active, port, ServerStanding::Active);
        let backup_view = read_own_group(&group.backup, group.backup_port)
            .map_err(fail)?;

        prop_assert!(resumed.is_ok(), "{resumed:?}");
        prop_assert_eq!(backup_view.standing, ServerStanding::Backup);
    }

    #[test]
    fn test_decide_and_act_property_a_backup_waits_for_its_turn(
        _round in 0_u8..1,
    ) {
        let group = start_backup_group(READY_TAKEOVER_SECONDS).map_err(fail)?;

        let backup = group.backup;
        let stopped_at = Instant::now();
        drop(group.hosting);
        let took_over = wait_until_standing(&backup, "active", TAKEOVER_LIMIT);
        let waited = stopped_at.elapsed();

        prop_assert!(took_over.is_ok(), "{took_over:?}");
        let turn = Duration::from_secs(READY_TAKEOVER_SECONDS);
        prop_assert!(waited >= turn, "{waited:?}");
    }

    #[test]
    fn test_apply_action_property_a_takeover_accepts_writes(
        _round in 0_u8..1,
    ) {
        let taken = start_and_take_over().map_err(fail)?;

        let created =
            create_project(
                &taken.backup,
                &taken.workspace_id,
                TAKEN_OVER_PROJECT,
            );
        let saved = read_hosted_state(&taken.backup).map_err(fail)?;

        prop_assert!(created.is_ok(), "{created:?}");
        let saved_text = saved["projects"].to_string();
        prop_assert!(saved_text.contains(TAKEN_OVER_PROJECT), "{saved_text}");
    }

    #[test]
    fn test_apply_action_property_a_takeover_is_audited_once(
        _round in 0_u8..1,
    ) {
        let taken = start_and_take_over().map_err(fail)?;

        let takeovers =
            count_audit_entries(&taken.backup, TAKEOVER_AUDIT_TEXT)?;

        prop_assert_eq!(takeovers, 1);
    }

    #[test]
    fn test_apply_action_property_a_resumed_active_accepts_writes(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let port = group.hosting.port;

        let active =
            group.hosting.device.stop_and_start_again().map_err(fail)?;
        wait_until_server_standing(&active, port, ServerStanding::Active)
            .map_err(fail)?;
        let created =
            create_project(&active, &group.workspace_id, RESUMED_PROJECT);

        prop_assert!(created.is_ok(), "{created:?}");
    }

    #[test]
    fn test_refresh_own_address_property_an_active_restart_is_recorded(
        restart_count in 1_usize..3,
    ) {
        let HostingDevice { mut device, port, .. } =
            host_a_server().map_err(fail)?;
        let mut taken_ports = Vec::new();

        for _ in 0..restart_count {
            let moved = restart_with_the_port_taken(device).map_err(fail)?;
            device = moved.device;
            taken_ports.push(moved.taken_port);
            wait_until_listed_address_is_current(&device, &device, port)
                .map_err(fail)?;
        }
        let updates = count_audit_entries(&device, ADDRESS_AUDIT_TEXT)?;

        prop_assert!(updates >= 1, "{updates}");
        prop_assert!(updates <= restart_count, "{updates}");
    }

    #[test]
    fn test_refresh_own_address_property_a_backup_restart_reaches_the_active(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let moved_backup =
            restart_with_the_port_taken(group.backup).map_err(fail)?;

        wait_until_listed_address_is_current(
            &moved_backup.device,
            &group.hosting.device,
            group.hosting.port,
        )
        .map_err(fail)?;
        let updates =
            count_audit_entries(&group.hosting.device, ADDRESS_AUDIT_TEXT)?;

        prop_assert!(updates >= 1, "{updates}");
    }

    #[test]
    fn test_refresh_own_address_property_a_current_address_writes_nothing(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        thread::sleep(SETTLE_PAUSE);

        let before = count_audit_entries(&hosting.device, ADDRESS_AUDIT_TEXT)?;
        thread::sleep(IDLE_PERIOD);
        let after = count_audit_entries(&hosting.device, ADDRESS_AUDIT_TEXT)?;

        prop_assert_eq!(before, 0);
        prop_assert_eq!(after, 0);
    }

    #[test]
    fn test_choose_leader_property_a_backup_copies_from_the_term_server(
        _round in 0_u8..1,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        let has_copy = find_device_copy(
            &group.hosting.device,
            group.hosting.port,
            &group.backup,
        )?;

        prop_assert!(has_copy);
    }

    #[test]
    fn test_choose_leader_property_the_returner_copies_from_the_new_term(
        _round in 0_u8..1,
    ) {
        let returned = take_over_and_return().map_err(fail)?;

        wait_until_copied(&returned.active, &returned.returned).map_err(fail)?;
        let has_copy = find_device_copy(
            &returned.active,
            returned.active_port,
            &returned.returned,
        )?;

        prop_assert!(has_copy);
    }

    #[test]
    fn test_choose_leader_property_a_lone_active_has_no_followers(
        _round in 0_u8..1,
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        let view =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;

        prop_assert!(view.copies.is_empty(), "{:?}", view.copies);
        prop_assert_eq!(view.standing, ServerStanding::Active);
    }
}

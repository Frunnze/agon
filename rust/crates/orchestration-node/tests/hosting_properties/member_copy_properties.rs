use std::collections::BTreeSet;
use std::thread;
use std::time::Duration;

use proptest::prelude::*;
use serde_json::Value;

use crate::backup_group::{
    STEADY_TAKEOVER_SECONDS, read_state_revision, shared_backup_group,
    start_backup_group, take_over_and_return,
};
use crate::hosting_desk::heavy_cases;
use crate::support::server_backups::{
    create_project, read_hosted_state, wait_until_copied,
};
use crate::support::test_device::fail;

const SAMPLE_PAUSE: Duration = Duration::from_millis(300);
const SAMPLE_COUNT: usize = 12;
const MISSED_PROJECT_PREFIX: &str = "missed-project";

fn list_project_keys(state: &Value) -> BTreeSet<String> {
    let mut keys = BTreeSet::new();
    if let Some(projects) = state["projects"].as_object() {
        for key in projects.keys() {
            keys.insert(key.clone());
        }
    }
    keys
}

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_member_links_new_property_a_started_backup_holds_the_copy(
        _round in 0_u8..1,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        let copied = wait_until_copied(&group.hosting.device, &group.backup)
            .map_err(fail)?;
        let source = read_hosted_state(&group.hosting.device).map_err(fail)?;

        prop_assert_eq!(&group.started["this_device"], "backup");
        prop_assert_eq!(
            &copied["server_group"]["term"],
            &source["server_group"]["term"]
        );
    }

    #[test]
    fn test_member_links_new_property_a_restarted_backup_copies_again(
        restart_count in 1_usize..3,
    ) {
        let mut group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;

        for _ in 0..restart_count {
            group = group.restart_the_backup().map_err(fail)?;
            let copied = group.write_and_wait_for_copy();
            prop_assert!(copied.is_ok(), "{copied:?}");
        }
    }

    #[test]
    fn test_member_links_new_property_copy_requests_name_the_device(
        _round in 0_u8..1,
    ) {
        let group = shared_backup_group().map_err(fail)?;
        let identity = group.backup.load_identity().map_err(fail)?;

        let view = group.read_active_group().map_err(fail)?;

        let copy = view
            .copies
            .iter()
            .find(|copy| copy.device_id == identity.device_id());
        let Some(copy) = copy else {
            return Err(fail(format!("no copy request: {:?}", view.copies)));
        };
        prop_assert!(copy.verified_revision <= view.revision);
    }

    #[test]
    fn test_member_links_fetch_replica_property_copies_follow_every_write(
        write_count in 1_usize..4,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        for _ in 0..write_count {
            let copied = group.write_and_wait_for_copy();
            prop_assert!(copied.is_ok(), "{copied:?}");
        }
    }

    #[test]
    fn test_member_links_fetch_replica_property_the_copy_invents_no_project(
        _round in 0_u8..1,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        let copied = group.write_and_wait_for_copy().map_err(fail)?;
        let source = read_hosted_state(&group.hosting.device).map_err(fail)?;

        let copied_keys = list_project_keys(&copied);
        let source_keys = list_project_keys(&source);
        prop_assert!(copied_keys.is_subset(&source_keys));
        prop_assert!(!copied_keys.is_empty());
    }

    #[test]
    fn test_member_links_fetch_replica_property_copied_revisions_never_fall(
        write_count in 1_usize..3,
    ) {
        let group = shared_backup_group().map_err(fail)?;
        let mut revisions: Vec<u64> = Vec::new();

        for _ in 0..write_count {
            group.write_and_wait_for_copy().map_err(fail)?;
            for _ in 0..SAMPLE_COUNT {
                let revision =
                    read_state_revision(&group.backup).map_err(fail)?;
                revisions.push(revision);
                thread::sleep(SAMPLE_PAUSE);
            }
        }

        for pair in revisions.windows(2) {
            prop_assert!(pair[0] <= pair[1], "{revisions:?}");
        }
    }

    #[test]
    fn test_member_links_client_for_property_one_link_carries_many_copies(
        write_count in 2_usize..5,
    ) {
        let group = shared_backup_group().map_err(fail)?;
        let first = read_state_revision(&group.backup).map_err(fail)?;

        for _ in 0..write_count {
            group.write_and_wait_for_copy().map_err(fail)?;
        }
        let last = read_state_revision(&group.backup).map_err(fail)?;

        let written = u64::try_from(write_count).map_err(fail)?;
        prop_assert!(last >= first + written, "{first} {last}");
    }

    #[test]
    fn test_member_links_client_for_property_the_returning_server_copies(
        _round in 0_u8..1,
    ) {
        let returned = take_over_and_return().map_err(fail)?;

        let caught_up =
            wait_until_copied(&returned.active, &returned.returned);

        prop_assert!(caught_up.is_ok(), "{caught_up:?}");
    }

    #[test]
    fn test_member_links_client_for_property_a_returning_backup_catches_up(
        missed_count in 1_usize..3,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let stopped = group.backup.stop();

        for index in 0..missed_count {
            let name = format!("{MISSED_PROJECT_PREFIX}-{index}");
            create_project(&group.hosting.device, &group.workspace_id, &name)
                .map_err(fail)?;
        }
        let backup = stopped.start_again().map_err(fail)?;
        let copied = wait_until_copied(&group.hosting.device, &backup);

        let copied = copied.map_err(fail)?;
        let copied_text = copied["projects"].to_string();
        for index in 0..missed_count {
            let name = format!("{MISSED_PROJECT_PREFIX}-{index}");
            prop_assert!(copied_text.contains(&name), "{copied_text}");
        }
    }
}

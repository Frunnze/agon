use std::fs;

use proptest::prelude::*;
use serde_json::json;
use tempfile::TempDir;

use crate::backup_fixtures::{list_server_device_ids, pair_backup_device};
use crate::hosted_files::{is_port_free, loopback_address};
use crate::runtime_steps::{
    host_on, hosted_directory_in, hosted_record_in, run_on, start_runtime,
};
use crate::support::hosting_steps::pick_free_port;
use crate::support::server_access::check_health_at;
use crate::support::server_backups::start_server_backup;
use crate::support::test_device::{fail, read_text};

const STOP_CASES: u32 = 3;
const STATE_FILE_NAME: &str = "state.json";

fn project_name_strategy() -> impl Strategy<Value = String> {
    "kept-[a-z]{3,10}"
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STOP_CASES))]

    #[test]
    fn test_stop_hosted_app_server_property_a_stopped_node_frees_the_port(
        cycle_count in 1_usize..3,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let first_runtime =
            start_runtime(data_directory.path(), port).map_err(fail)?;
        host_on(&first_runtime).map_err(fail)?;
        drop(first_runtime);

        for _ in 0..cycle_count {
            prop_assert!(is_port_free(port));
            let health = check_health_at(&loopback_address(port));
            prop_assert!(health.is_err(), "{:?}", health);
            let runtime =
                start_runtime(data_directory.path(), port).map_err(fail)?;
            prop_assert!(!is_port_free(port));
            drop(runtime);
        }
        prop_assert!(is_port_free(port));
    }

    #[test]
    fn test_stop_hosted_app_server_property_stopping_keeps_the_state(
        project_name in project_name_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let runtime =
            start_runtime(data_directory.path(), port).map_err(fail)?;
        let account = host_on(&runtime).map_err(fail)?;
        let workspace_id =
            read_text(&account, "/workspaces/0/id").map_err(fail)?;
        run_on(&runtime, &json!({
            "command": "create_project",
            "workspace_id": workspace_id,
            "name": project_name,
            "repositories": [],
        })).map_err(fail)?;

        drop(runtime);
        let server_directory = hosted_directory_in(data_directory.path());
        let state_path = server_directory.join(STATE_FILE_NAME);
        let state_text = fs::read_to_string(&state_path).map_err(fail)?;
        let restarted =
            start_runtime(data_directory.path(), port).map_err(fail)?;
        let projects = run_on(&restarted, &json!({
            "command": "list_projects",
            "workspace_id": workspace_id,
        }));

        prop_assert!(hosted_record_in(data_directory.path()).exists());
        prop_assert!(state_text.contains(&project_name));
        let projects_text = projects.map_err(fail)?.to_string();
        prop_assert!(projects_text.contains(&project_name));
    }
}

#[test]
fn test_stop_hosted_app_server_property_a_stopped_backup_stays_a_member() {
    let Ok(group) = pair_backup_device() else {
        panic!("the backup device pairs with the hosting device");
    };
    let started = start_server_backup(&group.backup);
    assert!(started.is_ok(), "{started:?}");
    let listed_before = list_server_device_ids(&group.hosting.device);

    let stopped = group.backup.stop();
    let listed_after = list_server_device_ids(&group.hosting.device);
    let port_was_freed = is_port_free(group.backup_port);
    drop(stopped);

    assert_eq!(listed_before.as_ref().map(Vec::len), Ok(2));
    assert_eq!(listed_after, listed_before);
    assert!(port_was_freed);
}

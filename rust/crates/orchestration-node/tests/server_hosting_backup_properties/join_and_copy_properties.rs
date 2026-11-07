use proptest::collection::{hash_set, vec};
use proptest::prelude::*;
use serde_json::Value;

use crate::backup_fixtures::{
    block_state_file, list_server_device_ids, pair_backup_device,
    read_own_device_id, read_own_standing,
};
use crate::support::server_backups::{
    create_project, read_hosted_state, start_server_backup,
};
use crate::support::test_device::fail;

const COPY_CASES: u32 = 3;
const BACKUP_STANDING: &str = "backup";
const SERVER_FAILED_PREFIX: &str = "the app server on this device failed: ";

fn project_names_strategy() -> impl Strategy<Value = Vec<String>> {
    hash_set("copied-[a-z]{3,10}", 1..4)
        .prop_map(|names| names.into_iter().collect())
}

fn blocking_names_strategy() -> impl Strategy<Value = Vec<String>> {
    vec("[a-z]{1,8}", 0..3)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(COPY_CASES))]

    #[test]
    fn test_join_and_copy_property_the_first_copy_holds_earlier_projects(
        project_names in project_names_strategy(),
    ) {
        let group = pair_backup_device().map_err(fail)?;
        for name in &project_names {
            create_project(&group.hosting.device, &group.workspace_id, name)
                .map_err(fail)?;
        }

        let started = start_server_backup(&group.backup);
        let copied_state = read_hosted_state(&group.backup);

        prop_assert!(started.is_ok(), "{:?}", started);
        let copied_projects = copied_state.map_err(fail)?["projects"]
            .to_string();
        for name in &project_names {
            prop_assert!(copied_projects.contains(name), "{}", name);
        }
    }

    #[test]
    fn test_join_and_copy_property_an_uninstallable_copy_is_refused(
        blocking_names in blocking_names_strategy(),
    ) {
        let group = pair_backup_device().map_err(fail)?;
        block_state_file(&group.backup, &blocking_names).map_err(fail)?;

        let refused = start_server_backup(&group.backup);

        let problem = refused.err().unwrap_or_default();
        prop_assert!(problem.starts_with(SERVER_FAILED_PREFIX), "{}", problem);
    }
}

#[test]
fn test_join_and_copy_property_the_group_lists_the_new_member() {
    let Ok(group) = pair_backup_device() else {
        panic!("the backup device pairs with the hosting device");
    };
    let Ok(backup_id) = read_own_device_id(&group.backup) else {
        panic!("the backup device names its id");
    };
    let listed_before = list_server_device_ids(&group.hosting.device);

    let started = start_server_backup(&group.backup);
    let listed_after = list_server_device_ids(&group.hosting.device);
    let standing = read_own_standing(&group.backup);

    assert!(started.is_ok(), "{started:?}");
    let Ok(listed_before) = listed_before else {
        panic!("the hosting device lists its servers");
    };
    assert!(!listed_before.contains(&backup_id), "{listed_before:?}");
    let Ok(listed_after) = listed_after else {
        panic!("the hosting device lists its servers after the join");
    };
    assert_eq!(listed_after.len(), listed_before.len() + 1);
    assert!(listed_after.contains(&backup_id), "{listed_after:?}");
    assert_eq!(standing, Ok(Value::from(BACKUP_STANDING)));
}

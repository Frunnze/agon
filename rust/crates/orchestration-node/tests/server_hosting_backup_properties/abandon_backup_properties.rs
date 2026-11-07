use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::Value;

use crate::backup_fixtures::{
    BackupGroup, block_state_file, list_server_device_ids, pair_backup_device,
    read_own_standing,
};
use crate::hosted_files::{is_port_free, list_left_server_files};
use crate::support::server_backups::{read_hosted_state, start_server_backup};
use crate::support::test_device::fail;

const ABANDON_CASES: u32 = 3;
const NO_STANDING: &str = "none";
const BACKUP_STANDING: &str = "backup";

fn blocking_names_strategy() -> impl Strategy<Value = Vec<String>> {
    vec("[a-z]{1,8}", 0..3)
}

fn pair_with_blocked_copy(
    blocking_names: &[String],
) -> Result<BackupGroup, TestCaseError> {
    let group = pair_backup_device().map_err(fail)?;
    block_state_file(&group.backup, blocking_names).map_err(fail)?;
    Ok(group)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ABANDON_CASES))]

    #[test]
    fn test_abandon_backup_property_a_refused_copy_leaves_no_files(
        blocking_names in blocking_names_strategy(),
    ) {
        let group = pair_with_blocked_copy(&blocking_names)?;

        let refused = start_server_backup(&group.backup);

        prop_assert!(refused.is_err(), "{:?}", refused);
        let left_files = list_left_server_files(&group.backup);
        prop_assert!(left_files.is_empty(), "{:?}", left_files);
        prop_assert!(is_port_free(group.backup_port));
    }

    #[test]
    fn test_abandon_backup_property_a_refused_copy_leaves_the_group(
        blocking_names in blocking_names_strategy(),
    ) {
        let group = pair_with_blocked_copy(&blocking_names)?;
        let listed_before = list_server_device_ids(&group.hosting.device);

        let refused = start_server_backup(&group.backup);
        let listed_after = list_server_device_ids(&group.hosting.device);
        let standing = read_own_standing(&group.backup);

        prop_assert!(refused.is_err(), "{:?}", refused);
        prop_assert_eq!(listed_after, listed_before);
        prop_assert_eq!(standing, Ok(Value::from(NO_STANDING)));
    }

    #[test]
    fn test_abandon_backup_property_a_retry_after_it_succeeds(
        blocking_names in blocking_names_strategy(),
    ) {
        let group = pair_with_blocked_copy(&blocking_names)?;

        let refused = start_server_backup(&group.backup);
        let retried = start_server_backup(&group.backup);
        let standing = read_own_standing(&group.backup);
        let copied_state = read_hosted_state(&group.backup);

        prop_assert!(refused.is_err(), "{:?}", refused);
        prop_assert!(retried.is_ok(), "{:?}", retried);
        prop_assert_eq!(standing, Ok(Value::from(BACKUP_STANDING)));
        prop_assert!(copied_state.is_ok(), "{:?}", copied_state);
    }
}

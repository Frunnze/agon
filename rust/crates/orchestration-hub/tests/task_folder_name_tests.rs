mod worktree_support;

use orchestration_hub::branch_names::TASK_BRANCH_PREFIX;
use orchestration_hub::task_folder_names::read_task_id;
use proptest::prelude::*;
use worktree_support::{
    any_canonical_address, any_hostile_title, any_lifetime, any_task_id,
    plan_or_fail, repository_at, request_for,
};

proptest! {
    #[test]
    fn test_read_task_id_property_reads_back_every_planned_folder(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);
        let plan = plan_or_fail(&request)?;
        let folder_name = plan
            .task_folder
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or_default()
            .to_owned();
        let branch_folder_name = plan
            .branch
            .strip_prefix(TASK_BRANCH_PREFIX)
            .unwrap_or_default()
            .to_owned();

        prop_assert_eq!(read_task_id(&folder_name), Some(task_id));
        prop_assert_eq!(read_task_id(&branch_folder_name), Some(task_id));
    }

    #[test]
    fn test_read_task_id_property_never_panics_on_any_name(
        folder_name in any::<String>(),
    ) {
        let task_id = read_task_id(&folder_name);

        if let Some(task_id) = task_id {
            let identifier = task_id.0.simple().to_string();
            prop_assert!(folder_name.contains(&identifier));
        }
    }

    #[test]
    fn test_read_task_id_property_ignores_names_without_a_task_id(
        folder_name in "[a-z-]{0,40}",
    ) {
        prop_assert_eq!(read_task_id(&folder_name), None);
    }
}

#[test]
fn ignores_upper_case_and_short_identifiers() {
    let upper_case = "fix-67E5504410B1426F9247BB680E5FE0C8";
    let short = "fix-67e5504410b1426f9247bb680e5fe0c";

    assert_eq!(read_task_id(upper_case), None);
    assert_eq!(read_task_id(short), None);
}

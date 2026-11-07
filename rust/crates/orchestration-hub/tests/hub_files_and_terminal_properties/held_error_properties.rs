use std::fs;

use orchestration_hub::held_work::list_held_work;
use orchestration_hub::worktree_roots::WorktreeRoots;
use orchestration_hub::worktrees::WorktreeError;
use proptest::prelude::*;

use crate::held_folders::{any_slug, create_held_folders, to_case_error};

const ERROR_CASES: u32 = 12;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ERROR_CASES))]

    #[test]
    fn test_read_folder_error_property_names_the_unreadable_root(
        is_cache_root in any::<bool>(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let blocked_root = if is_cache_root {
            folders.roots.cache_root.clone()
        } else {
            folders.roots.worktrees_root.clone()
        };
        fs::write(&blocked_root, "a file, not a folder")
            .map_err(to_case_error)?;

        let listed = list_held_work(&folders.roots);

        let Err(WorktreeError::ReadFolder { path, .. }) = listed else {
            return Err(TestCaseError::fail(format!("{listed:?}")));
        };
        prop_assert_eq!(path, blocked_root);
    }

    #[test]
    fn test_read_folder_error_property_message_names_the_folder(
        root_name in any_slug(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let blocked_root = folders.temporary.path().join(root_name);
        fs::write(&blocked_root, "a file").map_err(to_case_error)?;
        let roots = WorktreeRoots {
            cache_root: folders.roots.cache_root.clone(),
            worktrees_root: blocked_root.clone(),
        };

        let listed = list_held_work(&roots);

        let problem_text = listed.err().map(|problem| problem.to_string());
        let folder_text = format!("{blocked_root:?}");
        let names_the_folder = problem_text
            .is_some_and(|text| text.contains(&folder_text));
        prop_assert!(names_the_folder);
    }

    #[test]
    fn test_read_folder_error_property_worktrees_are_read_first(
        cache_is_blocked in any::<bool>(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        fs::write(&folders.roots.worktrees_root, "file")
            .map_err(to_case_error)?;
        if cache_is_blocked {
            fs::write(&folders.roots.cache_root, "file")
                .map_err(to_case_error)?;
        }

        let listed = list_held_work(&folders.roots);

        let Err(WorktreeError::ReadFolder { path, .. }) = listed else {
            return Err(TestCaseError::fail(format!("{listed:?}")));
        };
        prop_assert_eq!(path, folders.roots.worktrees_root.clone());
    }
}

use std::fs;
use std::path::{Path, PathBuf};

use orchestration_hub::protected_file_covers::{
    PLACEHOLDER_FOLDER_NAME, cover_protected_files,
};
use proptest::collection::btree_set;
use proptest::prelude::*;

use crate::cover_support::{
    SECRETS_FOLDER, TaskTree, any_plain_name, cover_or_fail, make_task_tree,
    mounts_for, protect,
};
use crate::target_folders::fail_with;

const COVER_CASES: u32 = 12;
const EMPTY_FOLDER_NAME: &str = "empty-folder";
const LEFTOVER_TEXT: &str = "left behind";
const SECRET_FILE: &str = "keys.txt";

fn empty_folder_beside(task_folder: &Path) -> Result<PathBuf, TestCaseError> {
    let parent = task_folder
        .parent()
        .ok_or_else(|| TestCaseError::fail("the task folder has no parent"))?;
    Ok(parent.join(PLACEHOLDER_FOLDER_NAME).join(EMPTY_FOLDER_NAME))
}

fn secrets_tree() -> Result<TaskTree, TestCaseError> {
    make_task_tree(&[format!("{SECRETS_FOLDER}/{SECRET_FILE}")], &[])
}

fn is_cover_refused(task_folder: &Path) -> bool {
    let mounts = mounts_for(task_folder);
    let protected = protect(&[SECRETS_FOLDER]);
    cover_protected_files(&mounts, &protected).is_err()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(COVER_CASES))]

    #[test]
    fn test_ensure_folder_is_empty_property_leftover_files_stop_the_cover(
        leftovers in btree_set(any_plain_name(), 1..4),
    ) {
        let tree = secrets_tree()?;
        let empty_folder = empty_folder_beside(&tree.task_folder)?;
        fs::create_dir_all(&empty_folder)
            .map_err(|problem| fail_with(&problem))?;
        for leftover in &leftovers {
            fs::write(empty_folder.join(leftover), LEFTOVER_TEXT)
                .map_err(|problem| fail_with(&problem))?;
        }

        prop_assert!(is_cover_refused(&tree.task_folder));
    }

    #[test]
    fn test_ensure_folder_is_empty_property_leftover_folders_stop_the_cover(
        leftovers in btree_set(any_plain_name(), 1..4),
    ) {
        let tree = secrets_tree()?;
        let empty_folder = empty_folder_beside(&tree.task_folder)?;
        for leftover in &leftovers {
            fs::create_dir_all(empty_folder.join(leftover))
                .map_err(|problem| fail_with(&problem))?;
        }

        prop_assert!(is_cover_refused(&tree.task_folder));
    }

    #[test]
    fn test_ensure_folder_is_empty_property_an_empty_folder_is_reused(
        cover_count in 1_usize..4,
    ) {
        let tree = secrets_tree()?;
        let empty_folder = empty_folder_beside(&tree.task_folder)?;
        fs::create_dir_all(&empty_folder)
            .map_err(|problem| fail_with(&problem))?;
        let protected = protect(&[SECRETS_FOLDER]);

        for _ in 0..cover_count {
            let covered = cover_or_fail(&tree.task_folder, &protected)?;
            let placeholder = &covered.placeholder_mounts[0].placeholder;
            prop_assert_eq!(placeholder, &empty_folder);
        }
        let entry_count = fs::read_dir(&empty_folder)
            .map_err(|problem| fail_with(&problem))?
            .count();
        prop_assert_eq!(entry_count, 0);
    }
}

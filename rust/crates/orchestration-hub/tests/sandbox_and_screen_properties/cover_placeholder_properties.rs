use std::collections::BTreeSet;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use orchestration_hub::protected_file_covers::{
    PLACEHOLDER_FOLDER_NAME, cover_protected_files,
};
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use proptest::collection::btree_set;
use proptest::prelude::*;

use crate::cover_support::{
    KEY_PATTERN, SECRETS_FOLDER, any_plain_name, covered_relative_paths,
    make_task_tree, mounts_for, protect,
};
use crate::target_folders::fail_with;

const COVER_CASES: u32 = 16;
const EMPTY_FOLDER_NAME: &str = "empty-folder";
const EMPTY_FILE_NAME: &str = "empty-file";
const LEFTOVER_TEXT: &str = "left behind";
const KEY_EXTENSION: &str = ".pem";

fn placeholder_folder(task_folder: &Path) -> Result<PathBuf, TestCaseError> {
    let parent = task_folder
        .parent()
        .ok_or_else(|| TestCaseError::fail("the task folder has no parent"))?;
    Ok(parent.join(PLACEHOLDER_FOLDER_NAME))
}

fn leave_leftovers(
    task_folder: &Path,
    leftovers: &BTreeSet<String>,
) -> Result<(), TestCaseError> {
    let empty_folder =
        placeholder_folder(task_folder)?.join(EMPTY_FOLDER_NAME);
    fs::create_dir_all(&empty_folder)
        .map_err(|problem| fail_with(&problem))?;
    for leftover in leftovers {
        fs::write(empty_folder.join(leftover), LEFTOVER_TEXT)
            .map_err(|problem| fail_with(&problem))?;
    }
    Ok(())
}

fn key_files(names: &BTreeSet<String>) -> Vec<String> {
    let mut files = Vec::new();
    for name in names {
        files.push(format!("certificates/{name}{KEY_EXTENSION}"));
    }
    files
}

fn cover_keys(task_folder: &Path) -> io::Result<WorkspaceMounts> {
    cover_protected_files(&mounts_for(task_folder), &protect(&[KEY_PATTERN]))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(COVER_CASES))]

    #[test]
    fn test_cover_protected_files_property_file_covers_ignore_leftovers(
        key_names in btree_set(any_plain_name(), 1..4),
        leftovers in btree_set(any_plain_name(), 1..4),
    ) {
        let tree = make_task_tree(&key_files(&key_names), &[])?;
        leave_leftovers(&tree.task_folder, &leftovers)?;

        let covered = cover_keys(&tree.task_folder)
            .map_err(|problem| fail_with(&problem))?;

        let empty_file =
            placeholder_folder(&tree.task_folder)?.join(EMPTY_FILE_NAME);
        prop_assert_eq!(covered.placeholder_mounts.len(), key_names.len());
        for placeholder_mount in &covered.placeholder_mounts {
            prop_assert_eq!(&placeholder_mount.placeholder, &empty_file);
        }
    }

    #[test]
    fn test_cover_protected_files_property_folder_covers_refuse_leftovers(
        key_names in btree_set(any_plain_name(), 0..3),
        leftovers in btree_set(any_plain_name(), 1..4),
    ) {
        let mut files = key_files(&key_names);
        files.push(format!("{SECRETS_FOLDER}/token.txt"));
        let tree = make_task_tree(&files, &[])?;
        leave_leftovers(&tree.task_folder, &leftovers)?;
        let protected = protect(&[KEY_PATTERN, SECRETS_FOLDER]);

        let covered =
            cover_protected_files(&mounts_for(&tree.task_folder), &protected);

        prop_assert!(covered.is_err());
    }

    #[test]
    fn test_cover_protected_files_property_leftovers_never_change_file_covers(
        key_names in btree_set(any_plain_name(), 0..4),
        leftovers in btree_set(any_plain_name(), 1..4),
    ) {
        let clean_tree = make_task_tree(&key_files(&key_names), &[])?;
        let littered_tree = make_task_tree(&key_files(&key_names), &[])?;
        leave_leftovers(&littered_tree.task_folder, &leftovers)?;

        let clean = cover_keys(&clean_tree.task_folder)
            .map_err(|problem| fail_with(&problem))?;
        let littered = cover_keys(&littered_tree.task_folder)
            .map_err(|problem| fail_with(&problem))?;

        prop_assert_eq!(
            covered_relative_paths(&littered)?,
            covered_relative_paths(&clean)?,
        );
    }
}

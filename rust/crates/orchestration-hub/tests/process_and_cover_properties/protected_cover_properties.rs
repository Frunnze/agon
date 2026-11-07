use std::fs;
use std::path::{Component, Path, PathBuf};

use orchestration_hub::protected_file_covers::{
    PLACEHOLDER_FOLDER_NAME, container_home_directory, cover_protected_files,
};
use orchestration_hub::workspace_mounts::{
    CONTAINER_WORKSPACE_DIRECTORY, PlaceholderMount,
};
use proptest::collection::{btree_set, vec};
use proptest::prelude::*;

use crate::cover_support::{
    KEY_PATTERN, SECRETS_FOLDER, any_plain_name, any_relative_folder,
    cover_or_fail, covered_relative_paths, join_relative, make_task_tree,
    mounts_for, protect,
};
use crate::target_folders::fail_with;

const COVER_CASES: u32 = 16;
const EMPTY_FOLDER_NAME: &str = "empty-folder";
const EMPTY_FILE_NAME: &str = "empty-file";
const LEFTOVER_TEXT: &str = "left behind";

fn any_key_file() -> impl Strategy<Value = String> {
    (any_relative_folder(), any_plain_name()).prop_map(|(folder, name)| {
        join_relative(&folder, &format!("{name}.pem"))
    })
}

fn placeholder_folder_of(
    task_folder: &Path,
) -> Result<PathBuf, TestCaseError> {
    let parent = task_folder
        .parent()
        .ok_or_else(|| TestCaseError::fail("the task folder has no parent"))?;
    Ok(parent.join(PLACEHOLDER_FOLDER_NAME))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(COVER_CASES))]

    #[test]
    fn test_container_home_directory_property_is_a_plain_absolute_folder(
        call_count in 1_usize..4,
    ) {
        let first_home = container_home_directory();

        for _ in 0..call_count {
            prop_assert_eq!(container_home_directory(), first_home.clone());
        }
        let home = Path::new(&first_home);
        prop_assert!(home.is_absolute());
        prop_assert!(!first_home.ends_with('/'));
        for component in home.components() {
            let is_plain =
                matches!(component, Component::RootDir | Component::Normal(_));
            prop_assert!(is_plain, "{first_home}");
        }
    }

    #[test]
    fn test_container_home_directory_property_lies_outside_the_workspace(
        call_count in 1_usize..4,
    ) {
        for _ in 0..call_count {
            let home_directory = container_home_directory();
            let home = Path::new(&home_directory);
            let workspace = Path::new(CONTAINER_WORKSPACE_DIRECTORY);

            prop_assert!(!home.starts_with(workspace));
            prop_assert!(!workspace.starts_with(home));
        }
    }

    #[test]
    fn test_cover_protected_files_property_keeps_earlier_covers_first(
        files in btree_set(any_key_file(), 1..5),
        earlier_count in 1_usize..3,
    ) {
        let file_list: Vec<String> = files.into_iter().collect();
        let tree = make_task_tree(&file_list, &[])?;
        let mut mounts = mounts_for(&tree.task_folder);
        for position in 0..earlier_count {
            mounts.placeholder_mounts.push(PlaceholderMount {
                covered_path: tree.task_folder.join(format!("e{position}")),
                placeholder: tree.root.path().join(EMPTY_FILE_NAME),
            });
        }

        let covered = cover_protected_files(&mounts, &protect(&[KEY_PATTERN]))
            .map_err(|problem| fail_with(&problem))?;

        let kept = &covered.placeholder_mounts[..earlier_count];
        prop_assert_eq!(kept, mounts.placeholder_mounts.as_slice());
        let added_count = covered.placeholder_mounts.len() - earlier_count;
        prop_assert_eq!(added_count, file_list.len());
    }

    #[test]
    fn test_prepare_placeholders_property_placeholders_sit_beside_the_task(
        files in btree_set(any_key_file(), 1..5),
    ) {
        let file_list: Vec<String> = files.into_iter().collect();
        let tree = make_task_tree(&file_list, &[])?;

        let protected = protect(&[KEY_PATTERN]);

        let covered = cover_or_fail(&tree.task_folder, &protected)?;

        let placeholder_folder = placeholder_folder_of(&tree.task_folder)?;
        for placeholder_mount in &covered.placeholder_mounts {
            let placeholder = &placeholder_mount.placeholder;
            prop_assert!(placeholder.starts_with(&placeholder_folder));
            prop_assert!(!placeholder.starts_with(&tree.task_folder));
        }
    }

    #[test]
    fn test_prepare_placeholders_property_reuses_and_empties_the_file(
        files in btree_set(any_key_file(), 1..4),
        leftover in "[a-z ]{1,20}",
        cover_count in 2_usize..4,
    ) {
        let file_list: Vec<String> = files.into_iter().collect();
        let tree = make_task_tree(&file_list, &[])?;
        let protected = protect(&[KEY_PATTERN]);
        let first = cover_or_fail(&tree.task_folder, &protected)?;
        let placeholder = first.placeholder_mounts[0].placeholder.clone();

        for _ in 1..cover_count {
            fs::write(&placeholder, &leftover)
                .map_err(|problem| fail_with(&problem))?;
            let again = cover_or_fail(&tree.task_folder, &protected)?;
            prop_assert_eq!(&again, &first);
        }

        let placeholder_text =
            fs::read(&placeholder).map_err(|problem| fail_with(&problem))?;
        prop_assert_eq!(placeholder_text, Vec::<u8>::new());
    }

    #[test]
    fn test_prepare_placeholders_property_folder_placeholder_stays_empty(
        leftovers in vec(any_plain_name(), 1..4),
    ) {
        let secrets = vec![format!("{SECRETS_FOLDER}/keys.txt")];
        let tree = make_task_tree(&secrets, &[])?;
        let empty_folder =
            placeholder_folder_of(&tree.task_folder)?.join(EMPTY_FOLDER_NAME);
        fs::create_dir_all(&empty_folder)
            .map_err(|problem| fail_with(&problem))?;
        for leftover in &leftovers {
            fs::write(empty_folder.join(leftover), LEFTOVER_TEXT)
                .map_err(|problem| fail_with(&problem))?;
        }

        let mounts = mounts_for(&tree.task_folder);
        let protected = protect(&[SECRETS_FOLDER]);

        let covered = cover_protected_files(&mounts, &protected);

        if let Ok(covered) = covered {
            let placeholder = &covered.placeholder_mounts[0].placeholder;
            let entries = fs::read_dir(placeholder)
                .map_err(|problem| fail_with(&problem))?
                .count();
            prop_assert_eq!(entries, 0, "{}", placeholder.display());
        }
    }

    #[test]
    fn test_find_protected_entries_property_stops_at_protected_folders(
        inner_files in btree_set(any_key_file(), 0..4),
        outer_folder in any_relative_folder(),
    ) {
        let secrets_folder = join_relative(&outer_folder, SECRETS_FOLDER);
        let mut files = Vec::new();
        for inner_file in &inner_files {
            files.push(format!("{secrets_folder}/{inner_file}"));
        }
        let folders = std::slice::from_ref(&secrets_folder);
        let tree = make_task_tree(&files, folders)?;
        let protected = protect(&[SECRETS_FOLDER, KEY_PATTERN]);

        let covered = cover_or_fail(&tree.task_folder, &protected)?;

        let covered_paths = covered_relative_paths(&covered)?;
        prop_assert_eq!(covered_paths, vec![secrets_folder]);
    }

    #[test]
    fn test_find_protected_entries_property_covers_are_sorted_and_unique(
        files in btree_set(any_key_file(), 1..8),
    ) {
        let file_list: Vec<String> = files.into_iter().collect();
        let tree = make_task_tree(&file_list, &[])?;

        let protected = protect(&[KEY_PATTERN]);

        let covered = cover_or_fail(&tree.task_folder, &protected)?;

        let covered_paths: Vec<&PathBuf> = covered
            .placeholder_mounts
            .iter()
            .map(|placeholder_mount| &placeholder_mount.covered_path)
            .collect();
        for pair in covered_paths.windows(2) {
            prop_assert!(pair[0] < pair[1]);
        }
        prop_assert_eq!(covered_paths.len(), file_list.len());
    }
}

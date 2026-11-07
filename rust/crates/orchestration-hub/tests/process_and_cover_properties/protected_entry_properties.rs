use std::fs;
use std::os::unix::fs::symlink;

use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::collection::btree_set;
use proptest::prelude::*;

use crate::cover_support::{
    KEY_PATTERN, SECRETS_FOLDER, any_plain_name, any_relative_folder,
    cover_or_fail, covered_relative_paths, join_relative, make_task_tree,
    protect,
};
use crate::process_support::{CaseOutcome, finish_within_time_limit};
use crate::target_folders::fail_with;

const COVER_CASES: u32 = 16;
const OUTSIDE_FOLDER_NAME: &str = "outside";
const LINK_NAME: &str = "linked";
const LOOP_NAME: &str = "loop";
const OTHER_PLACE_NAME: &str = "elsewhere";
const UNICODE_KEY_NAMES: [&str; 4] = ["ключ", "鍵", "clé", "🔑"];

fn any_unicode_key_file() -> impl Strategy<Value = String> {
    (
        any_relative_folder(),
        proptest::sample::select(UNICODE_KEY_NAMES.to_vec()),
    )
        .prop_map(|(folder, name)| {
            join_relative(&folder, &format!("{name}.pem"))
        })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(COVER_CASES))]

    #[test]
    fn test_describe_agent_path_property_unicode_names_match_patterns(
        files in btree_set(any_unicode_key_file(), 1..5),
    ) {
        let file_list: Vec<String> = files.into_iter().collect();
        let tree = make_task_tree(&file_list, &[])?;

        let protected = protect(&[KEY_PATTERN]);

        let covered = cover_or_fail(&tree.task_folder, &protected)?;

        prop_assert_eq!(covered_relative_paths(&covered)?, file_list);
    }

    #[test]
    fn test_describe_agent_path_property_rooted_patterns_match_one_place(
        folder in any_relative_folder(),
        other_folder in any_relative_folder(),
        name in any_plain_name(),
    ) {
        prop_assume!(name != OTHER_PLACE_NAME);
        let chosen = join_relative(&folder, &name);
        let other_place = join_relative(&other_folder, OTHER_PLACE_NAME);
        let other = join_relative(&other_place, &name);
        let tree = make_task_tree(&[chosen.clone(), other], &[])?;
        let rooted = format!("{CONTAINER_WORKSPACE_DIRECTORY}/{chosen}");

        let covered = cover_or_fail(&tree.task_folder, &protect(&[&rooted]))?;

        prop_assert_eq!(covered_relative_paths(&covered)?, vec![chosen]);
    }

    #[test]
    fn test_describe_agent_path_property_any_depth_patterns_match_everywhere(
        folders in btree_set(any_relative_folder(), 1..4),
        name in any_plain_name(),
    ) {
        let mut files = Vec::new();
        for folder in &folders {
            let has_same_name = folder.split('/').any(|part| part == name);
            prop_assume!(!has_same_name);
            let place = join_relative(OTHER_PLACE_NAME, folder);
            files.push(join_relative(&place, &name));
        }
        let tree = make_task_tree(&files, &[])?;

        let covered = cover_or_fail(&tree.task_folder, &protect(&[&name]))?;

        let mut covered_paths = covered_relative_paths(&covered)?;
        covered_paths.sort();
        files.sort();
        prop_assert_eq!(covered_paths, files);
    }

    #[test]
    fn test_read_entry_kind_property_placeholders_match_the_entry_kind(
        files in btree_set(any_plain_name(), 0..3),
        folder in any_relative_folder(),
    ) {
        let secrets_folder = join_relative(&folder, SECRETS_FOLDER);
        let mut file_list = Vec::new();
        for file in &files {
            file_list.push(format!("{file}.pem"));
        }
        let tree = make_task_tree(&file_list, &[secrets_folder])?;
        let protected = protect(&[KEY_PATTERN, SECRETS_FOLDER]);

        let covered = cover_or_fail(&tree.task_folder, &protected)?;

        prop_assert_eq!(covered.placeholder_mounts.len(), file_list.len() + 1);
        for placeholder_mount in &covered.placeholder_mounts {
            let covers_folder = placeholder_mount.covered_path.is_dir();
            let is_folder_placeholder = placeholder_mount.placeholder.is_dir();
            prop_assert_eq!(is_folder_placeholder, covers_folder);
        }
    }

    #[test]
    fn test_read_entry_kind_property_links_take_the_kind_of_their_target(
        target_is_folder in any::<bool>(),
        name in any_plain_name(),
    ) {
        let target = format!("{OUTSIDE_FOLDER_NAME}/{name}");
        let mut files = Vec::new();
        let mut folders = Vec::new();
        if target_is_folder {
            folders.push(target.clone());
        } else {
            files.push(target.clone());
        }
        let tree = make_task_tree(&files, &folders)?;
        let link = tree.task_folder.join(format!("{name}.pem"));
        symlink(tree.task_folder.join(&target), &link)
            .map_err(|problem| fail_with(&problem))?;

        let protected = protect(&[KEY_PATTERN]);

        let covered = cover_or_fail(&tree.task_folder, &protected)?;

        prop_assert_eq!(covered.placeholder_mounts.len(), 1);
        let placeholder = &covered.placeholder_mounts[0].placeholder;
        prop_assert_eq!(placeholder.is_dir(), target_is_folder);
    }

    #[test]
    fn test_read_entry_kind_property_dangling_links_hide_nothing(
        names in btree_set(any_plain_name(), 1..4),
    ) {
        let tree = make_task_tree(&[], &[])?;
        for name in &names {
            let missing = tree.root.path().join(format!("missing-{name}"));
            let link = tree.task_folder.join(format!("{name}.pem"));
            symlink(&missing, &link).map_err(|problem| fail_with(&problem))?;
        }

        let protected = protect(&[KEY_PATTERN]);

        let covered = cover_or_fail(&tree.task_folder, &protected)?;

        prop_assert_eq!(covered.placeholder_mounts.len(), 0);
    }

    #[test]
    fn test_find_protected_entries_property_does_not_follow_folder_links(
        names in btree_set(any_plain_name(), 1..4),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut outside_files = Vec::new();
            for name in &names {
                outside_files.push(format!("{name}.pem"));
            }
            let tree = make_task_tree(&[], &[])?;
            let outside = tree.root.path().join(OUTSIDE_FOLDER_NAME);
            fs::create_dir_all(&outside)
                .map_err(|problem| fail_with(&problem))?;
            for outside_file in &outside_files {
                fs::write(outside.join(outside_file), "key")
                    .map_err(|problem| fail_with(&problem))?;
            }
            symlink(&outside, tree.task_folder.join(LINK_NAME))
                .map_err(|problem| fail_with(&problem))?;
            symlink(&tree.task_folder, tree.task_folder.join(LOOP_NAME))
                .map_err(|problem| fail_with(&problem))?;

            let covered =
                cover_or_fail(&tree.task_folder, &protect(&[KEY_PATTERN]))?;

            prop_assert_eq!(covered.placeholder_mounts.len(), 0);
            Ok(())
        })?;
    }
}

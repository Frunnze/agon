use std::collections::{BTreeMap, BTreeSet};

use orchestration_core::repository_files::{
    RepositoryEntry, RepositoryEntryKind,
};
use proptest::prelude::*;

use crate::repository_copies::{
    FileTree, REPOSITORY_CASES, any_file_tree, create_repository,
    list_direct_children, list_main_folder,
};

const GITLINK_MODE: &str = "160000";

fn any_hostile_name() -> impl Strategy<Value = String> {
    prop_oneof![
        "[a-z]{1,4}\t[a-z]{0,4}",
        "[a-z]{1,4}\n[a-z]{1,4}",
        "-{1,2}[a-z]{1,6}",
        "[a-z]{1,3}[\"'\\\\ #:;=@{}]{1,3}[a-z]{0,3}",
        "[é中😀ü]{1,4}",
        "[a-z]{1,3}  [a-z]{1,3}",
        "[0-9]{1,6}",
    ]
}

fn byte_count(bytes: &[u8]) -> Option<u64> {
    u64::try_from(bytes.len()).ok()
}

fn names_of(entries: &[RepositoryEntry]) -> BTreeSet<String> {
    entries.iter().map(|entry| entry.name.clone()).collect()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REPOSITORY_CASES))]

    #[test]
    fn test_parse_tree_record_property_hostile_names_come_back_exactly(
        names in proptest::collection::btree_set(any_hostile_name(), 1..5),
        content in "[a-z]{0,10}",
    ) {
        let lower_names: BTreeSet<String> =
            names.iter().map(|name| name.to_lowercase()).collect();
        prop_assume!(lower_names.len() == names.len());
        let copy = create_repository()?;
        let files: FileTree = names
            .iter()
            .map(|name| (name.clone(), content.clone().into_bytes()))
            .collect();
        copy.commit_tree(&files)?;

        let entries = list_main_folder(&copy.open_reader()?, "")?;

        prop_assert_eq!(names_of(&entries), names);
        for entry in &entries {
            prop_assert_eq!(entry.kind, RepositoryEntryKind::File);
            prop_assert_eq!(entry.size, byte_count(content.as_bytes()));
        }
    }

    #[test]
    fn test_parse_tree_record_property_sizes_count_bytes_of_files_only(
        files in any_file_tree(),
    ) {
        let copy = create_repository()?;
        copy.commit_tree(&files)?;

        let entries = list_main_folder(&copy.open_reader()?, "")?;

        let children = list_direct_children(&files, "");
        prop_assert_eq!(entries.len(), children.len());
        for entry in &entries {
            let is_folder = children.get(&entry.name).copied();
            prop_assert_eq!(
                is_folder,
                Some(entry.kind == RepositoryEntryKind::Folder)
            );
            let content = files.get(&entry.name).cloned();
            let file_size = content.and_then(|content| byte_count(&content));
            let is_folder_entry = entry.kind == RepositoryEntryKind::Folder;
            let expected_size = if is_folder_entry { None } else { file_size };
            prop_assert_eq!(entry.size, expected_size);
        }
    }

    #[test]
    fn test_parse_tree_record_property_links_and_gitlinks_keep_the_listing(
        target in "[a-z./é]{1,30}",
        link_name in "[a-z]{1,6}",
        gitlink_name in "[a-z]{1,6}",
        file_name in "[a-z]{1,6}",
    ) {
        let distinct: BTreeSet<&String> =
            [&target, &link_name, &gitlink_name, &file_name]
                .into_iter()
                .collect();
        prop_assume!(distinct.len() == 4);
        let copy = create_repository()?;
        let files = BTreeMap::from([(file_name.clone(), b"text".to_vec())]);
        copy.add_link(&link_name, &target)?;
        let commit = copy.commit_tree(&files)?;
        let gitlink = format!("{GITLINK_MODE},{commit},{gitlink_name}");
        copy.git(&["update-index", "--add", "--cacheinfo", &gitlink])?;
        copy.git(&["commit", "--message", "Add a gitlink"])?;

        let entries = list_main_folder(&copy.open_reader()?, "")?;

        let by_name: BTreeMap<String, (RepositoryEntryKind, Option<u64>)> =
            entries
                .into_iter()
                .map(|entry| (entry.name, (entry.kind, entry.size)))
                .collect();
        let link_size = byte_count(target.as_bytes());
        prop_assert_eq!(
            by_name.get(&link_name),
            Some(&(RepositoryEntryKind::Link, link_size))
        );
        prop_assert_eq!(
            by_name.get(&file_name),
            Some(&(RepositoryEntryKind::File, Some(4)))
        );
        prop_assert!(by_name.len() <= 3);
    }
}

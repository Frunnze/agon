use std::collections::BTreeSet;

use orchestration_hub::repository_reading::RepositoryReadError;
use proptest::prelude::*;

use crate::hook_running::to_case_error;
use crate::raw_trees::{
    RAW_TREE_CASES, RawNode, RawTree, any_readable_names, any_unreadable_name,
    any_unreadable_names, commit_raw_tree, files_named, is_folder, list_root,
    listed_names, read_main_text, readable_files,
};
use crate::repository_copies::MAIN_BRANCH;

const HIDDEN_CONTENT: &[u8] = b"hidden";
const READABLE_FOLDER_NAME: &str = "folder+inner";
const INSIDE_FILE_NAME: &str = "inside.txt";
const LOSSY_TWIN_STEM: &str = "twin";
const REPLACEMENT_CHARACTER: char = '\u{FFFD}';
const SHOWN_TWIN_CONTENT: &str = "shown twin";

fn mixed_tree(
    readable: &BTreeSet<String>,
    unreadable: &BTreeSet<Vec<u8>>,
) -> RawTree {
    let mut tree = readable_files(readable);
    tree.extend(files_named(unreadable, HIDDEN_CONTENT));
    tree
}

fn lossy(name: &[u8]) -> String {
    String::from_utf8_lossy(name).into_owned()
}

fn any_lossy_twins() -> impl Strategy<Value = BTreeSet<Vec<u8>>> {
    let invalid_byte = prop_oneof![0x80_u8..0xC2, 0xF5_u8..=0xFF];
    proptest::collection::btree_set(invalid_byte, 2..5).prop_map(|bytes| {
        let mut twins = BTreeSet::new();
        for byte in bytes {
            let mut name = LOSSY_TWIN_STEM.as_bytes().to_vec();
            name.push(byte);
            twins.insert(name);
        }
        twins
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RAW_TREE_CASES))]

    #[test]
    fn test_read_tree_property_unreadable_names_are_never_listed(
        readable in any_readable_names(),
        unreadable in any_unreadable_names(),
    ) {
        let copy = commit_raw_tree(&mixed_tree(&readable, &unreadable))?;
        let reader = copy.open_reader()?;

        let entries = list_root(&reader)?;

        prop_assert_eq!(entries.len(), readable.len(), "{:?}", entries);
        prop_assert_eq!(listed_names(&entries), readable);
    }

    #[test]
    fn test_read_tree_property_every_listed_entry_opens(
        readable in any_readable_names(),
        inner_readable in any_readable_names(),
        unreadable in any_unreadable_names(),
        unreadable_folder in any_unreadable_name(),
    ) {
        let mut tree = mixed_tree(&readable, &unreadable);
        let inner_tree = mixed_tree(&inner_readable, &unreadable);
        let folder_name = READABLE_FOLDER_NAME.as_bytes().to_vec();
        tree.insert(folder_name, RawNode::Folder(inner_tree));
        let hidden_folder = readable_files(&inner_readable);
        tree.insert(unreadable_folder, RawNode::Folder(hidden_folder));
        let copy = commit_raw_tree(&tree)?;
        let reader = copy.open_reader()?;

        let root_entries = list_root(&reader)?;

        for entry in &root_entries {
            if is_folder(entry) {
                let inside = reader.list_folder(MAIN_BRANCH, &entry.name);
                prop_assert!(inside.is_ok(), "{:?}", inside);
                continue;
            }
            let text = read_main_text(&reader, &entry.name)?;
            prop_assert_eq!(text, entry.name.as_str());
        }
        let folders = root_entries.iter().filter(|entry| is_folder(entry));
        prop_assert_eq!(folders.count(), 1);
        let inner_entries = reader
            .list_folder(MAIN_BRANCH, READABLE_FOLDER_NAME)
            .map_err(to_case_error)?;
        prop_assert_eq!(listed_names(&inner_entries), inner_readable);
        for entry in &inner_entries {
            let path = format!("{READABLE_FOLDER_NAME}/{}", entry.name);
            let text = read_main_text(&reader, &path)?;
            prop_assert_eq!(text, entry.name.as_str());
        }
    }

    #[test]
    fn test_read_tree_property_unreadable_folder_hides_what_it_holds(
        unreadable_folder in any_unreadable_name(),
        inside_text in "[a-z ]{1,20}",
    ) {
        let mut inside = RawTree::new();
        let content = inside_text.into_bytes();
        let inside_name = INSIDE_FILE_NAME.as_bytes().to_vec();
        inside.insert(inside_name, RawNode::File(content));
        let mut tree = RawTree::new();
        tree.insert(unreadable_folder.clone(), RawNode::Folder(inside));
        let copy = commit_raw_tree(&tree)?;
        let reader = copy.open_reader()?;

        let root_entries = list_root(&reader)?;
        let lossy_folder = lossy(&unreadable_folder);
        let inside_path = format!("{lossy_folder}/{INSIDE_FILE_NAME}");
        let opened = reader.list_folder(MAIN_BRANCH, &lossy_folder);
        let read = reader.read_file(MAIN_BRANCH, &inside_path);

        prop_assert!(root_entries.is_empty(), "{:?}", root_entries);
        let is_not_a_folder =
            matches!(opened, Err(RepositoryReadError::NotAFolder(_)));
        prop_assert!(is_not_a_folder, "{:?}", opened);
        let is_not_found =
            matches!(read, Err(RepositoryReadError::NotFound(_)));
        prop_assert!(is_not_found, "{:?}", read);
    }

    #[test]
    fn test_split_readable_texts_property_unreadable_names_change_nothing(
        readable in any_readable_names(),
        unreadable in any_unreadable_names(),
    ) {
        let plain_copy = commit_raw_tree(&readable_files(&readable))?;
        let mixed_copy = commit_raw_tree(&mixed_tree(&readable, &unreadable))?;

        let plain_entries = list_root(&plain_copy.open_reader()?)?;
        let mixed_entries = list_root(&mixed_copy.open_reader()?)?;

        prop_assert_eq!(mixed_entries, plain_entries);
    }

    #[test]
    fn test_split_readable_texts_property_lossy_twins_never_appear(
        twins in any_lossy_twins(),
    ) {
        let mut tree = files_named(&twins, HIDDEN_CONTENT);
        let shown_twin = format!("{LOSSY_TWIN_STEM}{REPLACEMENT_CHARACTER}");
        let shown_content = SHOWN_TWIN_CONTENT.as_bytes().to_vec();
        let shown_name = shown_twin.clone().into_bytes();
        tree.insert(shown_name, RawNode::File(shown_content));
        let copy = commit_raw_tree(&tree)?;
        let reader = copy.open_reader()?;

        let entries = list_root(&reader)?;

        let shown_count =
            entries.iter().filter(|entry| entry.name == shown_twin).count();
        prop_assert_eq!(shown_count, 1, "{:?}", entries);
        prop_assert_eq!(entries.len(), 1, "{:?}", entries);
        let shown_text = read_main_text(&reader, &shown_twin)?;
        prop_assert_eq!(shown_text, SHOWN_TWIN_CONTENT);
    }

    #[test]
    fn test_split_readable_texts_property_only_unreadable_names_list_nothing(
        unreadable in any_unreadable_names(),
    ) {
        let copy = commit_raw_tree(&files_named(&unreadable, HIDDEN_CONTENT))?;
        let reader = copy.open_reader()?;

        let entries = list_root(&reader)?;

        prop_assert!(entries.is_empty(), "{:?}", entries);
        for name in &unreadable {
            let read = reader.read_file(MAIN_BRANCH, &lossy(name));
            let is_not_found =
                matches!(read, Err(RepositoryReadError::NotFound(_)));
            prop_assert!(is_not_found, "{:?}", read);
        }
    }
}

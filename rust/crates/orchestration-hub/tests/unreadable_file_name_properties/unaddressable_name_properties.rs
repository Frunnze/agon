use std::collections::BTreeSet;

use orchestration_core::repository_paths::normalize_file_path;
use proptest::prelude::*;

use crate::raw_trees::{
    RAW_TREE_CASES, RawNode, RawTree, any_readable_names, commit_raw_tree,
    files_named, list_root, listed_names, read_main_text, readable_files,
};
use crate::repository_copies::MAIN_BRANCH;

const HIDDEN_CONTENT: &[u8] = b"hidden";
const BACKSLASH: char = '\\';
const DOT_NAMES: [&str; 2] = [".", ".."];
const HOSTILE_READABLE_NAMES: [&str; 12] = [
    ".env",
    "...",
    "-rf",
    "--force",
    "HEAD",
    " leading space",
    "trailing space ",
    "a\u{FFFD}b",
    "中文.md",
    "é",
    "%2e%2e",
    "~home",
];

fn any_control_character() -> impl Strategy<Value = char> {
    prop_oneof![
        proptest::char::range('\u{1}', '\u{1F}'),
        Just('\u{7F}'),
        proptest::char::range('\u{80}', '\u{9F}'),
    ]
}

fn any_control_character_name() -> impl Strategy<Value = String> {
    ("[a-z]{0,3}", any_control_character(), "[a-z]{0,3}").prop_map(
        |(before, control_character, after)| {
            format!("{before}{control_character}{after}")
        },
    )
}

fn any_backslash_name() -> impl Strategy<Value = String> {
    ("[a-z]{0,3}", "[a-z]{0,3}")
        .prop_map(|(before, after)| format!("{before}{BACKSLASH}{after}"))
}

fn as_byte_names(names: &BTreeSet<String>) -> BTreeSet<Vec<u8>> {
    let mut byte_names = BTreeSet::new();
    for name in names {
        byte_names.insert(name.clone().into_bytes());
    }
    byte_names
}

fn tree_with_hidden(
    readable: &BTreeSet<String>,
    hidden: &BTreeSet<String>,
) -> RawTree {
    let mut tree = readable_files(readable);
    tree.extend(files_named(&as_byte_names(hidden), HIDDEN_CONTENT));
    tree
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RAW_TREE_CASES))]

    #[test]
    fn test_is_addressable_name_property_control_names_are_hidden(
        readable in any_readable_names(),
        hidden in proptest::collection::btree_set(
            any_control_character_name(),
            1..4,
        ),
    ) {
        let copy = commit_raw_tree(&tree_with_hidden(&readable, &hidden))?;
        let reader = copy.open_reader()?;

        let entries = list_root(&reader)?;

        prop_assert_eq!(listed_names(&entries), readable);
        for name in &hidden {
            let read = reader.read_file(MAIN_BRANCH, name);
            prop_assert!(read.is_err(), "{:?}", read);
        }
    }

    #[test]
    fn test_is_addressable_name_property_backslash_and_dot_names_are_hidden(
        readable in any_readable_names(),
        backslash_names in proptest::collection::btree_set(
            any_backslash_name(),
            1..4,
        ),
        dot_name_count in 0..=DOT_NAMES.len(),
    ) {
        let mut hidden = backslash_names.clone();
        for dot_name in DOT_NAMES.iter().take(dot_name_count) {
            hidden.insert((*dot_name).to_owned());
        }
        let mut tree = tree_with_hidden(&readable, &hidden);
        let folder_name = format!("folder{BACKSLASH}inside").into_bytes();
        let inside = readable_files(&readable);
        tree.insert(folder_name, RawNode::Folder(inside));
        let copy = commit_raw_tree(&tree)?;
        let reader = copy.open_reader()?;

        let entries = list_root(&reader)?;

        prop_assert_eq!(listed_names(&entries), readable);
    }

    #[test]
    fn test_is_addressable_name_property_hostile_readable_names_read_back(
        readable in any_readable_names(),
        hostile_count in 1..=HOSTILE_READABLE_NAMES.len(),
    ) {
        let mut names = readable.clone();
        for name in HOSTILE_READABLE_NAMES.iter().take(hostile_count) {
            names.insert((*name).to_owned());
        }
        let copy = commit_raw_tree(&readable_files(&names))?;
        let reader = copy.open_reader()?;

        let entries = list_root(&reader)?;

        prop_assert_eq!(listed_names(&entries), names);
        for entry in &entries {
            let normalized = normalize_file_path(&entry.name);
            prop_assert_eq!(normalized.as_deref(), Ok(entry.name.as_str()));
            let text = read_main_text(&reader, &entry.name)?;
            prop_assert_eq!(text, entry.name.as_str());
        }
    }
}

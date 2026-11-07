use std::collections::BTreeSet;

use orchestration_core::repository_files::{
    RepositoryEntry, RepositoryEntryKind,
};
use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;

const MAXIMUM_ENTRIES: usize = 12;
const ENTRY_NAME: &str = "[A-Za-zÀ-ÿ0-9._ -]{1,6}";

pub fn entry_kind() -> impl Strategy<Value = RepositoryEntryKind> {
    prop_oneof![
        Just(RepositoryEntryKind::Folder),
        Just(RepositoryEntryKind::File),
        Just(RepositoryEntryKind::Link),
    ]
}

fn entry_named(
    name: impl Strategy<Value = String>,
) -> impl Strategy<Value = RepositoryEntry> {
    (name, entry_kind(), option::of(any::<u64>()))
        .prop_map(|(name, kind, size)| RepositoryEntry { name, kind, size })
}

pub fn repository_entry() -> impl Strategy<Value = RepositoryEntry> {
    entry_named(any::<String>())
}

pub fn folder_listing() -> impl Strategy<Value = Vec<RepositoryEntry>> {
    let entry = entry_named(ENTRY_NAME);
    vec(entry, 0..MAXIMUM_ENTRIES).prop_map(|entries| {
        let mut seen_names = BTreeSet::new();
        let mut unique_entries = Vec::new();
        for entry in entries {
            if seen_names.insert(entry.name.clone()) {
                unique_entries.push(entry);
            }
        }
        unique_entries
    })
}

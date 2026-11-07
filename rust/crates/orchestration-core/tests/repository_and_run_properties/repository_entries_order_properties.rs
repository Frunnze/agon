use orchestration_core::repository_files::{
    RepositoryEntry, RepositoryEntryKind, order_repository_entries,
};
use proptest::prelude::*;

use crate::repository_entry_strategies::folder_listing;

fn names_of(entries: &[RepositoryEntry]) -> Vec<String> {
    let mut names = Vec::new();
    for entry in entries {
        names.push(entry.name.clone());
    }
    names
}

fn sorted_by_name(entries: &[RepositoryEntry]) -> Vec<RepositoryEntry> {
    let mut sorted = entries.to_vec();
    sorted.sort_by(|first, second| first.name.cmp(&second.name));
    sorted
}

fn is_folder_entry(entry: &RepositoryEntry) -> bool {
    entry.kind == RepositoryEntryKind::Folder
}

fn swap_files_and_links(entries: &[RepositoryEntry]) -> Vec<RepositoryEntry> {
    let mut swapped = Vec::new();
    for entry in entries {
        let kind = match entry.kind {
            RepositoryEntryKind::File => RepositoryEntryKind::Link,
            RepositoryEntryKind::Link => RepositoryEntryKind::File,
            RepositoryEntryKind::Folder => RepositoryEntryKind::Folder,
        };
        swapped.push(RepositoryEntry {
            kind,
            ..entry.clone()
        });
    }
    swapped
}

proptest! {
    #[test]
    fn test_order_repository_entries_property_keeps_every_entry(
        entries in folder_listing(),
    ) {
        let ordered = order_repository_entries(&entries);

        prop_assert_eq!(sorted_by_name(&ordered), sorted_by_name(&entries));
    }

    #[test]
    fn test_order_repository_entries_property_is_idempotent(
        entries in folder_listing(),
    ) {
        let ordered_once = order_repository_entries(&entries);

        let ordered_twice = order_repository_entries(&ordered_once);

        prop_assert_eq!(ordered_twice, ordered_once);
    }

    #[test]
    fn test_order_repository_entries_property_reversed_input_same_order(
        entries in folder_listing(),
    ) {
        let mut reversed_entries = entries.clone();
        reversed_entries.reverse();

        let ordered = order_repository_entries(&entries);
        let ordered_from_reversed =
            order_repository_entries(&reversed_entries);

        prop_assert_eq!(ordered_from_reversed, ordered);
    }

    #[test]
    fn test_is_folder_property_only_folders_lead(
        entries in folder_listing(),
    ) {
        let folder_count = entries.iter().filter(|entry| {
            is_folder_entry(entry)
        }).count();

        let ordered = order_repository_entries(&entries);

        for (position, entry) in ordered.iter().enumerate() {
            let is_leading = position < folder_count;
            prop_assert_eq!(is_folder_entry(entry), is_leading);
        }
    }

    #[test]
    fn test_is_folder_property_files_and_links_share_one_name_order(
        entries in folder_listing(),
    ) {
        let ordered = order_repository_entries(&entries);

        let mut lowercase_names = Vec::new();
        for entry in ordered.iter().filter(|entry| !is_folder_entry(entry)) {
            lowercase_names.push(entry.name.to_lowercase());
        }
        for pair in lowercase_names.windows(2) {
            prop_assert!(pair[0] <= pair[1], "{:?}", lowercase_names);
        }
    }

    #[test]
    fn test_is_folder_property_files_and_links_are_not_folders(
        entries in folder_listing(),
    ) {
        let swapped_entries = swap_files_and_links(&entries);

        let ordered = order_repository_entries(&entries);
        let ordered_swapped = order_repository_entries(&swapped_entries);

        prop_assert_eq!(names_of(&ordered_swapped), names_of(&ordered));
    }
}

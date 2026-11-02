use std::collections::BTreeSet;

use orchestration_core::repository_files::{
    FilePreview, RepositoryEntry, RepositoryEntryKind, RepositoryFile,
    order_repository_entries,
};
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};

fn any_entry() -> impl Strategy<Value = RepositoryEntry> {
    let kind = prop_oneof![
        Just(RepositoryEntryKind::Folder),
        Just(RepositoryEntryKind::File),
        Just(RepositoryEntryKind::Link),
    ];
    (
        "[A-Za-z0-9._-]{1,10}",
        kind,
        proptest::option::of(0..u64::MAX),
    )
        .prop_map(|(name, kind, size)| RepositoryEntry {
            name,
            kind,
            size,
        })
}

fn unique_entries() -> impl Strategy<Value = Vec<RepositoryEntry>> {
    vec(any_entry(), 0..20).prop_map(|entries| {
        let mut seen_names = BTreeSet::new();
        entries
            .into_iter()
            .filter(|entry| seen_names.insert(entry.name.clone()))
            .collect()
    })
}

fn any_preview() -> impl Strategy<Value = FilePreview> {
    prop_oneof![
        any::<String>().prop_map(|text| FilePreview::Text { text }),
        (1..u32::MAX, 1..u32::MAX, "[A-Za-z0-9+/=]{0,40}").prop_map(
            |(width, height, base64_content)| FilePreview::Image {
                width,
                height,
                base64_content,
            }
        ),
        Just(FilePreview::TooLarge),
        Just(FilePreview::Binary),
        Just(FilePreview::Link),
    ]
}

proptest! {
    #[test]
    fn test_order_repository_entries_property_puts_folders_first(
        entries in unique_entries(),
    ) {
        let ordered = order_repository_entries(&entries);

        let first_other = ordered
            .iter()
            .position(|entry| entry.kind != RepositoryEntryKind::Folder);
        if let Some(first_other) = first_other {
            prop_assert!(ordered[first_other..]
                .iter()
                .all(|entry| entry.kind != RepositoryEntryKind::Folder));
        }
    }

    #[test]
    fn test_order_repository_entries_property_sorts_names_ignoring_case(
        entries in unique_entries(),
    ) {
        let ordered = order_repository_entries(&entries);

        for pair in ordered.windows(2) {
            let same_group = (pair[0].kind == RepositoryEntryKind::Folder)
                == (pair[1].kind == RepositoryEntryKind::Folder);
            if same_group {
                prop_assert!(
                    pair[0].name.to_lowercase() <= pair[1].name.to_lowercase()
                );
            }
        }
    }

    #[test]
    fn test_order_repository_entries_property_ignores_the_given_order(
        entries in unique_entries(),
    ) {
        let mut reversed = entries.clone();
        reversed.reverse();

        let ordered = order_repository_entries(&entries);

        prop_assert_eq!(ordered.len(), entries.len());
        prop_assert_eq!(&ordered, &order_repository_entries(&reversed));
    }

    #[test]
    fn test_repository_file_property_round_trips_through_json(
        path in "[a-z/]{1,20}",
        size in any::<u64>(),
        preview in any_preview(),
    ) {
        let file = RepositoryFile { path, size, preview };

        let encoded = serde_json::to_value(&file);
        let decoded = encoded
            .and_then(serde_json::from_value::<RepositoryFile>);

        prop_assert_eq!(decoded.ok(), Some(file));
    }

    #[test]
    fn test_repository_file_fuzz_decoding_arbitrary_kinds_never_panics(
        kind in any::<String>(),
    ) {
        let candidate = json!({
            "path": "a",
            "size": 1,
            "preview": { "kind": kind },
        });

        let decoded = serde_json::from_value::<RepositoryFile>(candidate);

        let known = ["too_large", "binary", "link"];
        prop_assert_eq!(decoded.is_ok(), known.contains(&kind.as_str()));
    }
}

#[test]
fn test_file_preview_wire_format_names_each_kind() {
    let image = FilePreview::Image {
        width: 2,
        height: 3,
        base64_content: "AA==".to_owned(),
    };

    let encoded = serde_json::to_value(&image).ok();

    let expected: Value = json!({
        "kind": "image",
        "width": 2,
        "height": 3,
        "base64_content": "AA==",
    });
    assert_eq!(encoded, Some(expected));
    let too_large = serde_json::to_value(FilePreview::TooLarge).ok();
    assert_eq!(too_large, Some(json!({ "kind": "too_large" })));
}

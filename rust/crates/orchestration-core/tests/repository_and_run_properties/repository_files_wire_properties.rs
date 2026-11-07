use orchestration_core::repository_files::{
    FilePreview, RepositoryBranches, RepositoryEntry, RepositoryEntryKind,
    RepositoryFile,
};
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::repository_entry_strategies::{entry_kind, repository_entry};

const MAXIMUM_BRANCHES: usize = 6;
const ENTRY_KIND_NAMES: [&str; 3] = ["folder", "file", "link"];
const PREVIEW_KIND_NAMES: [&str; 5] =
    ["text", "image", "too_large", "binary", "link"];

fn branch_names() -> impl Strategy<Value = Vec<String>> {
    vec(any::<String>(), 0..MAXIMUM_BRANCHES)
}

fn file_preview() -> impl Strategy<Value = FilePreview> {
    prop_oneof![
        any::<String>().prop_map(|text| FilePreview::Text { text }),
        (any::<u32>(), any::<u32>(), any::<String>()).prop_map(
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

fn preview_kind_name(preview: &FilePreview) -> &'static str {
    match preview {
        FilePreview::Text { .. } => "text",
        FilePreview::Image { .. } => "image",
        FilePreview::TooLarge => "too_large",
        FilePreview::Binary => "binary",
        FilePreview::Link => "link",
    }
}

fn kind_name(kind: RepositoryEntryKind) -> &'static str {
    match kind {
        RepositoryEntryKind::Folder => "folder",
        RepositoryEntryKind::File => "file",
        RepositoryEntryKind::Link => "link",
    }
}

fn field_names(encoded: Option<&Value>) -> Vec<String> {
    let Some(Value::Object(fields)) = encoded else {
        return Vec::new();
    };
    fields.keys().cloned().collect()
}

proptest! {
    #[test]
    fn test_repository_branches_serialize_property_round_trips(
        branches in branch_names(),
        task_branches in branch_names(),
    ) {
        let listing = RepositoryBranches { branches, task_branches };

        let decoded = serde_json::to_value(&listing)
            .and_then(serde_json::from_value::<RepositoryBranches>);

        prop_assert_eq!(decoded.ok(), Some(listing));
    }

    #[test]
    fn test_repository_branches_serialize_property_writes_both_lists(
        branches in branch_names(),
        task_branches in branch_names(),
    ) {
        let listing = RepositoryBranches {
            branches: branches.clone(),
            task_branches: task_branches.clone(),
        };

        let encoded = serde_json::to_value(&listing).ok();

        let expected = json!({
            "branches": branches,
            "task_branches": task_branches,
        });
        prop_assert_eq!(encoded, Some(expected));
    }

    #[test]
    fn test_repository_branches_default_property_lists_no_branch(
        branch in any::<String>(),
    ) {
        let empty_listing = RepositoryBranches::default();

        prop_assert!(!empty_listing.branches.contains(&branch));
        prop_assert!(!empty_listing.task_branches.contains(&branch));
        let encoded = serde_json::to_value(&empty_listing).ok();
        let expected = json!({ "branches": [], "task_branches": [] });
        prop_assert_eq!(encoded, Some(expected));
    }

    #[test]
    fn test_repository_entry_kind_serialize_property_round_trips(
        kind in entry_kind(),
    ) {
        let decoded = serde_json::to_value(kind)
            .and_then(serde_json::from_value::<RepositoryEntryKind>);

        prop_assert_eq!(decoded.ok(), Some(kind));
    }

    #[test]
    fn test_repository_entry_kind_serialize_property_uses_documented_names(
        kind in entry_kind(),
    ) {
        let encoded = serde_json::to_value(kind).ok();

        prop_assert_eq!(encoded, Some(json!(kind_name(kind))));
    }

    #[test]
    fn test_repository_entry_kind_deserialize_property_refuses_other_names(
        name in any::<String>(),
    ) {
        prop_assume!(!ENTRY_KIND_NAMES.contains(&name.as_str()));

        let decoded =
            serde_json::from_value::<RepositoryEntryKind>(json!(name));

        prop_assert!(decoded.is_err());
    }

    #[test]
    fn test_repository_entry_serialize_property_round_trips(
        entry in repository_entry(),
    ) {
        let decoded = serde_json::to_value(&entry)
            .and_then(serde_json::from_value::<RepositoryEntry>);

        prop_assert_eq!(decoded.ok(), Some(entry));
    }

    #[test]
    fn test_repository_entry_serialize_property_writes_documented_fields(
        entry in repository_entry(),
    ) {
        let encoded = serde_json::to_value(&entry).ok();

        let expected = json!({
            "name": entry.name,
            "kind": kind_name(entry.kind),
            "size": entry.size,
        });
        prop_assert_eq!(encoded, Some(expected));
    }

    #[test]
    fn test_repository_entry_deserialize_property_reads_a_missing_size(
        name in any::<String>(),
        kind in entry_kind(),
    ) {
        let document = json!({
            "name": name,
            "kind": kind_name(kind),
            "size": null,
        });

        let decoded = serde_json::from_value::<RepositoryEntry>(document);

        let expected = RepositoryEntry { name, kind, size: None };
        prop_assert_eq!(decoded.ok(), Some(expected));
    }

    #[test]
    fn test_file_preview_serialize_property_round_trips(
        preview in file_preview(),
    ) {
        let decoded = serde_json::to_value(&preview)
            .and_then(serde_json::from_value::<FilePreview>);

        prop_assert_eq!(decoded.ok(), Some(preview));
    }

    #[test]
    fn test_file_preview_serialize_property_tags_the_documented_kind(
        preview in file_preview(),
    ) {
        let encoded = serde_json::to_value(&preview).ok();

        let tag = encoded.as_ref().and_then(|document| document.get("kind"));
        prop_assert_eq!(tag, Some(&json!(preview_kind_name(&preview))));
    }

    #[test]
    fn test_file_preview_deserialize_property_refuses_other_kinds(
        kind in any::<String>(),
    ) {
        prop_assume!(!PREVIEW_KIND_NAMES.contains(&kind.as_str()));

        let decoded = serde_json::from_value::<FilePreview>(json!({
            "kind": kind,
            "text": "",
        }));

        prop_assert!(decoded.is_err());
    }

    #[test]
    fn test_repository_file_serialize_property_writes_documented_fields(
        path in any::<String>(),
        size in any::<u64>(),
        preview in file_preview(),
    ) {
        let file = RepositoryFile { path, size, preview };

        let encoded = serde_json::to_value(&file).ok();

        let mut names = field_names(encoded.as_ref());
        names.sort();
        prop_assert_eq!(names, vec!["path", "preview", "size"]);
    }

    #[test]
    fn test_repository_file_serialize_property_keeps_every_size(
        path in any::<String>(),
        size in prop_oneof![Just(u64::MAX), Just(0_u64), any::<u64>()],
    ) {
        let file = RepositoryFile {
            path,
            size,
            preview: FilePreview::Binary,
        };

        let encoded = serde_json::to_value(&file).ok();

        let written_size = encoded
            .as_ref()
            .and_then(|document| document.get("size"))
            .and_then(Value::as_u64);
        prop_assert_eq!(written_size, Some(size));
    }

    #[test]
    fn test_repository_file_serialize_property_nests_the_tagged_preview(
        path in any::<String>(),
        size in any::<u64>(),
        preview in file_preview(),
    ) {
        let expected_preview = serde_json::to_value(&preview).ok();
        let file = RepositoryFile { path, size, preview };

        let encoded = serde_json::to_value(&file).ok();

        let written_preview = encoded
            .as_ref()
            .and_then(|document| document.get("preview"))
            .cloned();
        prop_assert_eq!(written_preview, expected_preview);
    }
}

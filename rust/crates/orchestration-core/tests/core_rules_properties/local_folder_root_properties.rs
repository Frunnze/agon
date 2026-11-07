use orchestration_core::local_folders::{
    LocalFolderProblem, normalize_folder_path,
};
use proptest::collection::vec;
use proptest::prelude::*;

const MAXIMUM_FOLDER_PARTS: usize = 4;
const FOLDER_SEPARATORS: [char; 2] = ['/', '\\'];

fn folder_part() -> impl Strategy<Value = String> {
    "[A-Za-z0-9_][A-Za-z0-9_-]{0,6}"
}

fn folder_parts() -> impl Strategy<Value = Vec<String>> {
    vec(folder_part(), 1..MAXIMUM_FOLDER_PARTS)
}

fn folder_separator() -> impl Strategy<Value = char> {
    proptest::sample::select(FOLDER_SEPARATORS.to_vec())
}

proptest! {
    #[test]
    fn test_split_folder_root_property_takes_any_drive_and_separator(
        drive in proptest::char::range('A', 'Z')
            .prop_union(proptest::char::range('a', 'z')),
        separator in folder_separator(),
        parts in folder_parts(),
    ) {
        let below_root = parts.join(&separator.to_string());
        let path = format!("{drive}:{separator}{below_root}");

        prop_assert_eq!(normalize_folder_path(&path), Ok(path.clone()));
    }

    #[test]
    fn test_split_folder_root_property_refuses_roots_that_are_not_drives(
        drive in prop_oneof![
            proptest::char::range('0', '9'),
            Just('_'),
            Just('\u{e9}'),
            Just('\u{1f600}'),
        ],
        separator in folder_separator(),
        parts in folder_parts(),
        has_drive_separator in any::<bool>(),
    ) {
        let below_root = parts.join("/");
        let path = if has_drive_separator {
            format!("{drive}:{separator}{below_root}")
        } else {
            format!("{drive}{below_root}")
        };

        prop_assert_eq!(
            normalize_folder_path(&path),
            Err(LocalFolderProblem::RelativePath(path.clone()))
        );
    }

    #[test]
    fn test_split_folder_root_property_needs_a_separator_after_the_drive(
        drive in proptest::char::range('A', 'Z'),
        parts in folder_parts(),
    ) {
        let path = format!("{drive}:{}", parts.join("\\"));

        prop_assert_eq!(
            normalize_folder_path(&path),
            Err(LocalFolderProblem::RelativePath(path.clone()))
        );
    }

    #[test]
    fn test_split_folder_root_property_keeps_one_unix_root(
        parts in folder_parts(),
        extra_root_slashes in 0_usize..3,
    ) {
        let below_root = parts.join("/");
        let path = format!("{}/{below_root}", "/".repeat(extra_root_slashes));

        let normalized = normalize_folder_path(&path);

        if extra_root_slashes == 0 {
            prop_assert_eq!(normalized, Ok(path.clone()));
        } else {
            prop_assert_eq!(
                normalized,
                Err(LocalFolderProblem::UnsafePath(path.clone()))
            );
        }
    }

    #[test]
    fn test_split_folder_root_property_never_panics_on_short_text(
        text in "[A-Za-z:/\\\\\u{e9}\u{1f600}]{0,4}",
    ) {
        let normalized = normalize_folder_path(&text);

        if let Ok(path) = normalized {
            prop_assert_eq!(normalize_folder_path(&path), Ok(path.clone()));
        }
    }
}

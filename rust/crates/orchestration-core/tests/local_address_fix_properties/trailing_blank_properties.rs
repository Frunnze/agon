use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{
    LOCAL_ADDRESS_PREFIX, LocalFolder, LocalFolderProblem,
    normalize_folder_path, parse_local_address, render_local_address,
};
use proptest::collection::vec;
use proptest::prelude::*;

const MAXIMUM_FOLDER_PARTS: usize = 4;
const TRAILING_BLANKS_AND_SEPARATORS: &str = "[ \u{a0}\u{3000}/\\\\]{1,5}";
const ONLY_SPACES_AND_SEPARATORS: &str = "[ \u{3000}/\\\\]{0,5}";
const HOSTILE_FOLDER_TEXT: &str =
    "([A-Za-z]:)?[/\\\\]?[a-zA-Z0-9 \u{3000}/\\\\.:]{0,12}";

fn device_text() -> impl Strategy<Value = String> {
    "[a-z0-9-]{1,12}"
}

fn folder_root() -> impl Strategy<Value = String> {
    prop_oneof![Just("/".to_owned()), "[A-Za-z]:[/\\\\]"]
}

fn folder_part() -> impl Strategy<Value = String> {
    "[A-Za-z0-9_]([A-Za-z0-9 _.-]{0,6}[A-Za-z0-9_])?"
}

fn absolute_folder() -> impl Strategy<Value = String> {
    (folder_root(), vec(folder_part(), 1..MAXIMUM_FOLDER_PARTS))
        .prop_map(|(root, parts)| format!("{root}{}", parts.join("/")))
}

fn address_of(device: &str, path: &str) -> String {
    format!("{LOCAL_ADDRESS_PREFIX}{device}:{path}")
}

fn folder_of(device: &str, path: &str) -> LocalFolder {
    LocalFolder {
        device_id: DeviceId(device.to_owned()),
        path: path.to_owned(),
    }
}

fn unsafe_path_of(written_path: &str) -> LocalFolderProblem {
    LocalFolderProblem::UnsafePath(written_path.trim().to_owned())
}

proptest! {
    #[test]
    fn test_normalize_folder_path_property_drops_blanks_between_separators(
        path in absolute_folder(),
        trailing in TRAILING_BLANKS_AND_SEPARATORS,
    ) {
        let written_path = format!("{path}{trailing}");

        prop_assert_eq!(normalize_folder_path(&written_path), Ok(path));
    }

    #[test]
    fn test_normalize_folder_path_property_never_ends_with_a_blank(
        text in HOSTILE_FOLDER_TEXT,
    ) {
        let Ok(path) = normalize_folder_path(&text) else {
            return Ok(());
        };

        prop_assert!(!path.ends_with(char::is_whitespace));
        prop_assert_eq!(normalize_folder_path(&path), Ok(path.clone()));
    }

    #[test]
    fn test_normalize_folder_path_property_refuses_a_root_with_only_blanks(
        root in folder_root(),
        trailing in ONLY_SPACES_AND_SEPARATORS,
    ) {
        let written_path = format!("{root}{trailing}");

        prop_assert_eq!(
            normalize_folder_path(&written_path),
            Err(unsafe_path_of(&written_path))
        );
    }

    #[test]
    fn test_normalize_folder_path_property_keeps_blank_inner_parts(
        path in absolute_folder(),
        blank_part in "[ \u{3000}]{1,3}",
        tail in folder_part(),
    ) {
        let written_path = format!("{path}/{blank_part}\\{tail}");

        prop_assert_eq!(
            normalize_folder_path(&written_path),
            Ok(written_path.clone())
        );
    }

    #[test]
    fn test_parse_local_address_property_drops_blanks_between_separators(
        device in device_text(),
        path in absolute_folder(),
        trailing in TRAILING_BLANKS_AND_SEPARATORS,
    ) {
        let address = address_of(&device, &format!("{path}{trailing}"));

        prop_assert_eq!(
            parse_local_address(&address),
            Ok(folder_of(&device, &path))
        );
    }

    #[test]
    fn test_parse_local_address_property_hostile_text_is_stable(
        device in device_text(),
        folder_text in HOSTILE_FOLDER_TEXT,
    ) {
        let address = address_of(&device, &folder_text);
        let Ok(folder) = parse_local_address(&address) else {
            return Ok(());
        };

        let rendered = render_local_address(&folder)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(parse_local_address(&rendered), Ok(folder));
    }

    #[test]
    fn test_parse_local_address_property_refuses_a_root_with_only_blanks(
        device in device_text(),
        root in folder_root(),
        trailing in ONLY_SPACES_AND_SEPARATORS,
    ) {
        let written_path = format!("{root}{trailing}");
        let address = address_of(&device, &written_path);

        prop_assert_eq!(
            parse_local_address(&address),
            Err(unsafe_path_of(&written_path))
        );
    }

    #[test]
    fn test_render_local_address_property_drops_blanks_between_separators(
        device in device_text(),
        path in absolute_folder(),
        trailing in TRAILING_BLANKS_AND_SEPARATORS,
    ) {
        let folder = folder_of(&device, &format!("{path}{trailing}"));

        prop_assert_eq!(
            render_local_address(&folder),
            Ok(address_of(&device, &path))
        );
    }

    #[test]
    fn test_render_local_address_property_renders_parsed_text_unchanged(
        device in device_text(),
        folder_text in HOSTILE_FOLDER_TEXT,
    ) {
        let Ok(rendered) = render_local_address(
            &folder_of(&device, &folder_text),
        ) else {
            return Ok(());
        };

        let folder = parse_local_address(&rendered)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(render_local_address(&folder), Ok(rendered));
    }

    #[test]
    fn test_render_local_address_property_refuses_a_root_with_only_blanks(
        device in device_text(),
        root in folder_root(),
        trailing in ONLY_SPACES_AND_SEPARATORS,
    ) {
        let written_path = format!("{root}{trailing}");

        prop_assert_eq!(
            render_local_address(&folder_of(&device, &written_path)),
            Err(unsafe_path_of(&written_path))
        );
    }
}

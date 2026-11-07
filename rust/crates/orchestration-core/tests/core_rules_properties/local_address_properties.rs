use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{
    LOCAL_ADDRESS_PREFIX, LocalFolder, LocalFolderProblem, is_local_address,
    normalize_folder_path, parse_local_address, render_local_address,
    validate_new_folder_name,
};
use proptest::collection::vec;
use proptest::prelude::*;

const MAXIMUM_FOLDER_PARTS: usize = 4;

fn device_text() -> impl Strategy<Value = String> {
    "[a-z0-9-]{1,12}"
}

fn bad_device_text() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(String::new()),
        "[a-z0-9-]{0,4}[A-Z_.:/ \u{e9}][a-z0-9-]{0,4}",
    ]
}

fn folder_part() -> impl Strategy<Value = String> {
    "[A-Za-z0-9_][A-Za-z0-9 _.:-]{0,6}[A-Za-z0-9_]"
}

fn absolute_folder() -> impl Strategy<Value = String> {
    let unix = vec(folder_part(), 1..MAXIMUM_FOLDER_PARTS)
        .prop_map(|parts| format!("/{}", parts.join("/")));
    let windows = ("[A-Za-z]", vec(folder_part(), 1..MAXIMUM_FOLDER_PARTS))
        .prop_map(|(drive, parts)| format!("{drive}:\\{}", parts.join("\\")));
    prop_oneof![unix, windows]
}

fn render_text(
    device: &str,
    path: &str,
) -> Result<String, LocalFolderProblem> {
    render_local_address(&LocalFolder {
        device_id: DeviceId(device.to_owned()),
        path: path.to_owned(),
    })
}

fn address_of(device: &str, path: &str) -> String {
    format!("{LOCAL_ADDRESS_PREFIX}{device}:{path}")
}

proptest! {
    #[test]
    fn test_is_local_address_property_rendered_addresses_are_local(
        device in device_text(),
        path in absolute_folder(),
    ) {
        let address = render_text(&device, &path)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert!(is_local_address(&address));
    }

    #[test]
    fn test_is_local_address_property_follows_the_prefix_alone(
        text in ".*",
    ) {
        let prefixed = format!("{LOCAL_ADDRESS_PREFIX}{text}");

        prop_assert!(is_local_address(&prefixed));
        prop_assert_eq!(
            is_local_address(&text),
            text.starts_with(LOCAL_ADDRESS_PREFIX)
        );
    }

    #[test]
    fn test_render_local_address_property_holds_the_normalized_path(
        device in device_text(),
        path in absolute_folder(),
        trailing_separators in "[/\\\\]{0,3}",
    ) {
        let written_path = format!(" {path}{trailing_separators} ");

        let rendered = render_text(&device, &written_path);
        let normalized = normalize_folder_path(&written_path);

        prop_assert_eq!(
            rendered,
            normalized.map(|normalized| address_of(&device, &normalized))
        );
    }

    #[test]
    fn test_parse_local_address_property_refuses_text_without_the_prefix(
        text in "[^l].*",
    ) {
        prop_assert_eq!(
            parse_local_address(&text),
            Err(LocalFolderProblem::MalformedAddress(text.clone()))
        );
    }

    #[test]
    fn test_parse_local_address_property_keeps_colons_in_the_folder(
        device in device_text(),
        path in absolute_folder(),
    ) {
        let address = address_of(&device, &path);

        let folder = parse_local_address(&address)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(folder.device_id, DeviceId(device));
        prop_assert_eq!(folder.path, path);
    }

    #[test]
    fn test_parse_local_address_property_is_stable_through_render(
        text in "local:[a-z0-9:-]{0,6}[/\\\\]?[a-zA-Z0-9 /\\\\.:]{0,12}",
    ) {
        let Ok(folder) = parse_local_address(&text) else {
            return Ok(());
        };

        let rendered = render_local_address(&folder)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
        let parsed_again = parse_local_address(&rendered);

        prop_assert_eq!(parsed_again, Ok(folder));
    }

    #[test]
    fn test_validate_device_id_property_accepts_lowercase_digits_and_dashes(
        device in device_text(),
        path in absolute_folder(),
    ) {
        prop_assert!(render_text(&device, &path).is_ok());
        prop_assert!(parse_local_address(&address_of(&device, &path)).is_ok());
    }

    #[test]
    fn test_validate_device_id_property_refuses_any_other_device_text(
        device in bad_device_text(),
        path in absolute_folder(),
    ) {
        prop_assert_eq!(
            render_text(&device, &path),
            Err(LocalFolderProblem::InvalidDeviceId(device.clone()))
        );
    }

    #[test]
    fn test_validate_device_id_property_parsing_refuses_the_same_text(
        device in bad_device_text().prop_filter(
            "a colon ends the device part of an address",
            |device| !device.contains(':'),
        ),
        path in absolute_folder(),
    ) {
        prop_assert_eq!(
            parse_local_address(&address_of(&device, &path)),
            Err(LocalFolderProblem::InvalidDeviceId(device.clone()))
        );
    }

    #[test]
    fn test_validate_new_folder_name_property_adds_exactly_one_folder(
        parent in absolute_folder(),
        name in "[ ]{0,2}[A-Za-z0-9 _.-]{1,8}[ ]{0,2}",
    ) {
        if validate_new_folder_name(&name).is_err() {
            return Ok(());
        }
        let parent_path = normalize_folder_path(&parent)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
        let new_folder = format!("{parent_path}/{name}");

        prop_assert_eq!(normalize_folder_path(&new_folder), Ok(new_folder));
    }

    #[test]
    fn test_validate_new_folder_name_property_names_the_refused_text(
        name in "[a-z]{0,3}[/\\\\\\x00-\\x1f][a-z]{0,3}",
    ) {
        let problem = validate_new_folder_name(&name).err();

        let quoted_name = format!("{name:?}");
        let names_the_text = problem
            .as_ref()
            .is_some_and(|problem| problem.to_string().contains(&quoted_name));
        prop_assert_eq!(
            problem,
            Some(LocalFolderProblem::UnsafeFolderName(name.clone()))
        );
        prop_assert!(names_the_text);
    }
}

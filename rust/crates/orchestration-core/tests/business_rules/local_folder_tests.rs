use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{
    LocalFolder, LocalFolderProblem, find_folder_device, is_local_address,
    normalize_folder_path, parse_local_address, render_local_address,
};
use orchestration_core::repository_address::{
    AddressProblem, parse_repository_address,
};
use orchestration_core::workspace::{AgentAccess, Repository};
use proptest::collection::vec;
use proptest::prelude::*;

const MAXIMUM_FOLDER_PARTS: usize = 5;
const MAXIMUM_TRAILING_SEPARATORS: usize = 3;
const MAXIMUM_REPOSITORIES: usize = 4;
const WINDOWS_DRIVE_LETTER: char = 'C';

fn device_id() -> impl Strategy<Value = DeviceId> {
    "[0-9a-f]{32}".prop_map(DeviceId)
}

fn folder_part() -> impl Strategy<Value = String> {
    prop_oneof![
        "[A-Za-z0-9_-]",
        "[A-Za-z0-9_-][A-Za-z0-9 _.-]{0,8}[A-Za-z0-9_-]",
    ]
}

fn unix_folder_path() -> impl Strategy<Value = String> {
    vec(folder_part(), 1..MAXIMUM_FOLDER_PARTS)
        .prop_map(|parts| format!("/{}", parts.join("/")))
}

fn windows_folder_path() -> impl Strategy<Value = String> {
    ("[A-Z]", vec(folder_part(), 1..MAXIMUM_FOLDER_PARTS))
        .prop_map(|(drive, parts)| format!("{drive}:\\{}", parts.join("\\")))
}

fn folder_path() -> impl Strategy<Value = String> {
    prop_oneof![unix_folder_path(), windows_folder_path()]
}

fn local_folder() -> impl Strategy<Value = LocalFolder> {
    (device_id(), folder_path())
        .prop_map(|(device_id, path)| LocalFolder { device_id, path })
}

fn github_address() -> impl Strategy<Value = String> {
    "github\\.com/[a-z][a-z0-9-]{0,8}/[a-z][a-z0-9_-]{0,8}"
}

fn repository_at(address: String) -> Repository {
    Repository {
        address,
        default_branch: "main".to_owned(),
        agent_access: AgentAccess::PushAfterApproval,
    }
}

fn local_repository(
    folder: &LocalFolder,
) -> Result<Repository, TestCaseError> {
    let address = render_local_address(folder)
        .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
    Ok(repository_at(address))
}

#[test]
fn test_render_local_address_pins_the_documented_format() {
    let billing_folder = std::env::temp_dir().join("billing");
    let billing_path = billing_folder.display().to_string();
    let folder = LocalFolder {
        device_id: DeviceId("3f2a9c".to_owned()),
        path: format!("{billing_path}/"),
    };

    assert_eq!(
        render_local_address(&folder),
        Ok(format!("local:3f2a9c:{billing_path}"))
    );
}

#[test]
fn test_normalize_folder_path_refuses_the_root_and_blank_text() {
    let windows_drive_root = format!("{WINDOWS_DRIVE_LETTER}:\\");

    assert!(normalize_folder_path("/").is_err());
    assert!(normalize_folder_path(&windows_drive_root).is_err());
    assert_eq!(
        normalize_folder_path("   "),
        Err(LocalFolderProblem::EmptyPath)
    );
}

proptest! {
    #[test]
    fn test_normalize_folder_path_property_canonical_paths_are_stable(
        path in folder_path(),
    ) {
        prop_assert_eq!(normalize_folder_path(&path), Ok(path));
    }

    #[test]
    fn test_normalize_folder_path_property_trailing_separators_are_dropped(
        path in unix_folder_path(),
        separator_count in 1..MAXIMUM_TRAILING_SEPARATORS,
    ) {
        let typed = format!("  {path}{}  ", "/".repeat(separator_count));

        prop_assert_eq!(normalize_folder_path(&typed), Ok(path));
    }

    #[test]
    fn test_normalize_folder_path_property_relative_paths_are_refused(
        parts in vec(folder_part(), 1..MAXIMUM_FOLDER_PARTS),
    ) {
        let path = parts.join("/");

        prop_assert_eq!(
            normalize_folder_path(&path),
            Err(LocalFolderProblem::RelativePath(path.clone()))
        );
    }

    #[test]
    fn test_normalize_folder_path_property_dot_parts_are_refused(
        path in unix_folder_path(),
        dots in "(\\.|\\.\\.)",
        tail in folder_part(),
    ) {
        let unsafe_path = format!("{path}/{dots}/{tail}");

        prop_assert_eq!(
            normalize_folder_path(&unsafe_path),
            Err(LocalFolderProblem::UnsafePath(unsafe_path.clone()))
        );
    }

    #[test]
    fn test_normalize_folder_path_property_control_characters_are_refused(
        path in unix_folder_path(),
        control in "[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f]",
    ) {
        let unsafe_path = format!("{path}{control}x");

        prop_assert!(matches!(
            normalize_folder_path(&unsafe_path),
            Err(LocalFolderProblem::UnsafePath(_))
        ));
    }

    #[test]
    fn test_normalize_folder_path_fuzz_results_are_absolute_and_stable(
        text in any::<String>(),
    ) {
        if let Ok(path) = normalize_folder_path(&text) {
            prop_assert_eq!(normalize_folder_path(&path), Ok(path.clone()));
            prop_assert!(!path.ends_with('/') && !path.ends_with('\\'));
        }
    }

    #[test]
    fn test_render_local_address_property_parse_is_its_inverse(
        folder in local_folder(),
    ) {
        let address = render_local_address(&folder)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert!(is_local_address(&address));
        prop_assert_eq!(parse_local_address(&address), Ok(folder));
    }

    #[test]
    fn test_render_local_address_property_refuses_bad_device_ids(
        device_text in "[A-Z: /]{0,6}",
        path in unix_folder_path(),
    ) {
        let folder = LocalFolder {
            device_id: DeviceId(device_text.clone()),
            path,
        };

        prop_assert_eq!(
            render_local_address(&folder),
            Err(LocalFolderProblem::InvalidDeviceId(device_text))
        );
    }

    #[test]
    fn test_parse_local_address_fuzz_results_render_back_to_themselves(
        text in any::<String>(),
    ) {
        let prefixed = format!("local:{text}");

        if let Ok(folder) = parse_local_address(&prefixed) {
            let address = render_local_address(&folder)
                .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
            prop_assert_eq!(parse_local_address(&address), Ok(folder));
        }
    }

    #[test]
    fn test_is_local_address_property_github_addresses_are_not_local(
        address in github_address(),
    ) {
        prop_assert!(!is_local_address(&address));
        prop_assert!(parse_local_address(&address).is_err());
    }

    #[test]
    fn test_parse_repository_address_property_local_addresses_are_canonical(
        folder in local_folder(),
    ) {
        let address = render_local_address(&folder)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
        let typed = format!(" {address}/ ");

        prop_assert_eq!(parse_repository_address(&typed), Ok(address));
    }

    #[test]
    fn test_parse_repository_address_property_bad_local_paths_are_refused(
        device_id in device_id(),
        parts in vec(folder_part(), 1..MAXIMUM_FOLDER_PARTS),
    ) {
        let path = parts.join("/");
        let address = format!("local:{}:{path}", device_id.0);

        prop_assert_eq!(
            parse_repository_address(&address),
            Err(AddressProblem::LocalFolder(
                LocalFolderProblem::RelativePath(path)
            ))
        );
    }

    #[test]
    fn test_find_folder_device_property_github_projects_have_no_device(
        addresses in vec(github_address(), 0..MAXIMUM_REPOSITORIES),
    ) {
        let repositories: Vec<Repository> =
            addresses.into_iter().map(repository_at).collect();

        prop_assert_eq!(find_folder_device(&repositories), Ok(None));
    }

    #[test]
    fn test_find_folder_device_property_one_device_holds_every_folder(
        device_id in device_id(),
        paths in vec(folder_path(), 1..MAXIMUM_REPOSITORIES),
        addresses in vec(github_address(), 0..MAXIMUM_REPOSITORIES),
    ) {
        let mut repositories: Vec<Repository> =
            addresses.into_iter().map(repository_at).collect();
        for path in paths {
            let device_id = device_id.clone();
            let folder = LocalFolder { device_id, path };
            repositories.push(local_repository(&folder)?);
        }

        let found = find_folder_device(&repositories);
        prop_assert_eq!(found, Ok(Some(device_id)));
    }

    #[test]
    fn test_find_folder_device_property_two_devices_are_refused(
        first in local_folder(),
        second in local_folder(),
    ) {
        prop_assume!(first.device_id != second.device_id);
        let repositories =
            vec![local_repository(&first)?, local_repository(&second)?];

        prop_assert_eq!(
            find_folder_device(&repositories),
            Err(LocalFolderProblem::SeveralDevices)
        );
    }
}

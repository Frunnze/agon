mod sandbox_support;

use std::collections::BTreeMap;
use std::path::PathBuf;

use orchestration_core::device::SandboxKind;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::sandbox::{
    ContainerSettings, SandboxError, wrap_in_sandbox,
};
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use proptest::prelude::*;
use sandbox_support::{
    any_engine, any_hosts, any_inner_command, any_mounts, any_settings,
    wrap_in_container,
};

fn any_unsafe_folder() -> impl Strategy<Value = PathBuf> {
    prop_oneof![
        Just(PathBuf::from("/")),
        Just(PathBuf::from("")),
        "[a-z]{1,8}(/[a-z]{1,8}){0,2}".prop_map(PathBuf::from),
        "/[a-z]{1,8}/\\.\\.(/[a-z]{1,8}){0,2}".prop_map(PathBuf::from),
    ]
}

fn any_unsafe_git_directory() -> impl Strategy<Value = PathBuf> {
    prop_oneof![
        any_unsafe_folder(),
        "[a-z]{1,8}/\\.git".prop_map(PathBuf::from),
        "/[a-z]{1,8}/\\.\\./\\.git".prop_map(PathBuf::from),
        "/[a-z]{1,8}/[a-z]{1,8}".prop_map(PathBuf::from),
        "/[a-z]{1,5}[,\"][a-z]{0,5}/\\.git".prop_map(PathBuf::from),
    ]
}

proptest! {
    #[test]
    fn test_wrap_in_sandbox_property_unsafe_task_folder_is_rejected(
        kind in prop_oneof![
            Just(SandboxKind::Container),
            Just(SandboxKind::LocalProcess),
        ],
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        task_folder in any_unsafe_folder(),
    ) {
        let mounts = WorkspaceMounts {
            task_folder: task_folder.clone(),
            ..mounts
        };

        let wrapped =
            wrap_in_sandbox(kind, &settings, &command, &mounts, &[]);

        let expected = SandboxError::UnsafeWorkspaceDirectory(task_folder);
        prop_assert_eq!(wrapped, Err(expected));
    }

    #[test]
    fn test_wrap_in_sandbox_property_mount_breaking_task_folder_is_rejected(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        task_folder in "/[a-z]{1,5}[,\"][a-z]{0,5}".prop_map(PathBuf::from),
    ) {
        let mounts = WorkspaceMounts {
            task_folder: task_folder.clone(),
            ..mounts
        };

        let wrapped = wrap_in_container(&settings, &command, &mounts, &[]);

        let expected = SandboxError::UnsafeWorkspaceDirectory(task_folder);
        prop_assert_eq!(wrapped, Err(expected));
    }

    #[test]
    fn test_wrap_in_sandbox_property_unsafe_git_directory_is_rejected(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        git_directory in any_unsafe_git_directory(),
    ) {
        let mut git_directories = mounts.git_directories.clone();
        git_directories.push(git_directory.clone());
        let mounts = WorkspaceMounts {
            git_directories,
            ..mounts
        };

        let wrapped = wrap_in_container(&settings, &command, &mounts, &[]);

        let expected = SandboxError::UnsafeGitDirectory(git_directory);
        prop_assert_eq!(wrapped, Err(expected));
    }

    #[test]
    fn test_wrap_in_sandbox_property_invalid_allowed_host_is_rejected(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        valid_hosts in any_hosts(),
        host in prop_oneof![
            Just(String::new()),
            "[a-z]{0,5}[, \t\n][a-z]{0,5}",
        ],
    ) {
        let mut hosts = valid_hosts;
        hosts.push(host.clone());

        let wrapped = wrap_in_container(&settings, &command, &mounts, &hosts);

        let expected = Err(SandboxError::InvalidAllowedHost(host));
        prop_assert_eq!(wrapped, expected);
    }

    #[test]
    fn test_wrap_in_sandbox_property_invalid_image_is_rejected(
        engine in any_engine(),
        command in any_inner_command(),
        mounts in any_mounts(),
        image in prop_oneof![
            Just(String::new()),
            "-[a-z]{0,8}",
            "[a-z]{1,4} [a-z]{1,4}",
        ],
    ) {
        let settings = ContainerSettings { engine: engine.0, image };

        let wrapped = wrap_in_container(&settings, &command, &mounts, &[]);

        let expected = Err(SandboxError::InvalidImage(settings.image));
        prop_assert_eq!(wrapped, expected);
    }

    #[test]
    fn test_wrap_in_sandbox_property_invalid_environment_name_is_rejected(
        (settings, _program) in any_settings(),
        mounts in any_mounts(),
        name in prop_oneof![
            Just(String::new()),
            "[0-9][A-Z]{0,4}",
            "[A-Z]{1,4}[=\\- ][A-Z]{0,4}",
        ],
    ) {
        let environment =
            BTreeMap::from([(name.clone(), "value".to_string())]);
        let command = CommandSpecification {
            program: "claude".to_string(),
            arguments: Vec::new(),
            environment,
            working_directory: None,
        };

        let wrapped = wrap_in_container(&settings, &command, &mounts, &[]);

        let expected = SandboxError::InvalidEnvironmentName(name);
        prop_assert_eq!(wrapped, Err(expected));
    }
}

use std::collections::BTreeMap;

use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::sandbox::{
    ContainerEngine, ContainerSettings, SandboxError,
};
use proptest::prelude::*;

use crate::hostile_mounts::{
    DockerMount, HostileMounts, WORKSPACE, any_hostile_name,
    any_mounts_named_by, any_safe_name, container_options, intended_mounts,
    mount_values, read_mount_like_docker,
};
use crate::sandbox_support::{
    any_engine, any_hosts, any_inner_command, any_settings, wrap_in_container,
};

const AGENT_PROGRAM: &str = "claude";
const AGENT_IMAGE: &str = "agent-image";
const EQUALS_NAME_PATTERN: &str = "[a-z]{0,3}=[a-z=]{0,3}";

pub fn agent_command(arguments: &[&str]) -> CommandSpecification {
    CommandSpecification {
        program: AGENT_PROGRAM.to_owned(),
        arguments: arguments.iter().map(ToString::to_string).collect(),
        environment: BTreeMap::new(),
        working_directory: None,
    }
}

pub fn agent_settings(engine: ContainerEngine) -> ContainerSettings {
    ContainerSettings {
        engine,
        image: AGENT_IMAGE.to_owned(),
    }
}

pub fn read_wrapped_mounts(
    hostile: &HostileMounts,
) -> Result<Vec<Option<DockerMount>>, SandboxError> {
    let command = agent_command(&["--mount"]);
    let settings = agent_settings(ContainerEngine::Docker);
    let wrapped =
        wrap_in_container(&settings, &command, &hostile.mounts, &[])?;
    let mut docker_mounts = Vec::new();
    for value in mount_values(container_options(&wrapped, &command)) {
        docker_mounts.push(read_mount_like_docker(&value));
    }
    Ok(docker_mounts)
}

fn read_or_fail(
    hostile: &HostileMounts,
) -> Result<Vec<Option<DockerMount>>, TestCaseError> {
    read_wrapped_mounts(hostile)
        .map_err(|problem| TestCaseError::fail(problem.to_string()))
}

fn intended(hostile: &HostileMounts) -> Vec<Option<DockerMount>> {
    intended_mounts(hostile).into_iter().map(Some).collect()
}

proptest! {
    #[test]
    fn test_wrap_in_container_property_docker_reads_every_mount_as_intended(
        hostile in any_mounts_named_by(any_hostile_name()),
    ) {
        let Ok(docker_mounts) = read_wrapped_mounts(&hostile) else {
            return Ok(());
        };

        prop_assert_eq!(docker_mounts, intended(&hostile));
    }

    #[test]
    fn test_wrap_in_container_property_paths_without_breaking_characters_pass(
        hostile in any_mounts_named_by(any_safe_name()),
    ) {
        let docker_mounts = read_or_fail(&hostile)?;

        prop_assert_eq!(docker_mounts, intended(&hostile));
    }

    #[test]
    fn test_wrap_in_container_property_inner_command_follows_the_image(
        (settings, program) in any_settings(),
        command in any_inner_command(),
        hostile in any_mounts_named_by(any_safe_name()),
        hosts in any_hosts(),
    ) {
        let wrapped =
            wrap_in_container(&settings, &command, &hostile.mounts, &hosts)
                .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        let options = container_options(&wrapped, &command);
        let rest = &wrapped.arguments[options.len()..];
        prop_assert_eq!(&wrapped.program, program);
        prop_assert_eq!(&rest[0], &settings.image);
        prop_assert_eq!(&rest[1], &command.program);
        prop_assert_eq!(&rest[2..], command.arguments.as_slice());
        prop_assert_eq!(wrapped.working_directory, None);
    }

    #[test]
    fn test_describe_mounts_property_task_folder_is_mounted_first(
        hostile in any_mounts_named_by(any_safe_name()),
    ) {
        let docker_mounts = read_or_fail(&hostile)?;

        let expected = DockerMount {
            source: hostile.mounts.task_folder.display().to_string(),
            target: WORKSPACE.to_owned(),
            is_read_only: false,
        };
        prop_assert_eq!(&docker_mounts[0], &Some(expected));
    }

    #[test]
    fn test_describe_mounts_property_git_directories_keep_their_paths(
        hostile in any_mounts_named_by(any_safe_name()),
    ) {
        let docker_mounts = read_or_fail(&hostile)?;

        let git_directories = &hostile.mounts.git_directories;
        let git_mounts = &docker_mounts[1..=git_directories.len()];
        let pairs = git_mounts.iter().zip(git_directories);
        for (git_mount, git_directory) in pairs {
            let shown = git_directory.display().to_string();
            let expected = DockerMount {
                source: shown.clone(),
                target: shown,
                is_read_only: false,
            };
            prop_assert_eq!(git_mount, &Some(expected));
        }
    }

    #[test]
    fn test_describe_mounts_property_only_placeholders_are_read_only(
        hostile in any_mounts_named_by(any_safe_name()),
    ) {
        let docker_mounts = read_or_fail(&hostile)?;

        let mut read_only_count = 0;
        for docker_mount in docker_mounts.iter().flatten() {
            read_only_count += usize::from(docker_mount.is_read_only);
        }
        let placeholder_count = hostile.mounts.placeholder_mounts.len();
        let writable_count = docker_mounts.len() - read_only_count;
        prop_assert_eq!(read_only_count, placeholder_count);
        prop_assert_eq!(
            writable_count,
            1 + hostile.mounts.git_directories.len(),
        );
    }

    #[test]
    fn test_bind_mount_property_equals_signs_stay_inside_the_value(
        hostile in any_mounts_named_by(EQUALS_NAME_PATTERN.boxed()),
    ) {
        let docker_mounts = read_or_fail(&hostile)?;

        prop_assert_eq!(docker_mounts, intended(&hostile));
    }

    #[test]
    fn test_bind_mount_property_covered_targets_stay_inside_the_workspace(
        hostile in any_mounts_named_by(any_hostile_name()),
    ) {
        let Ok(docker_mounts) = read_wrapped_mounts(&hostile) else {
            return Ok(());
        };

        let workspace_child = format!("{WORKSPACE}/");
        for docker_mount in docker_mounts.iter().flatten() {
            let target = &docker_mount.target;
            if docker_mount.is_read_only {
                prop_assert!(target.starts_with(&workspace_child));
                prop_assert!(!target.contains("/../"));
            }
        }
    }

    #[test]
    fn test_bind_mount_property_read_only_flag_is_the_last_field(
        (engine, _program) in any_engine(),
        hostile in any_mounts_named_by(any_safe_name()),
    ) {
        let command = agent_command(&[]);
        let settings = agent_settings(engine);
        let wrapped =
            wrap_in_container(&settings, &command, &hostile.mounts, &[])
                .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        let values = mount_values(container_options(&wrapped, &command));
        let placeholder_count = hostile.mounts.placeholder_mounts.len();
        let first_cover = values.len() - placeholder_count;
        for (position, value) in values.iter().enumerate() {
            let is_cover = position >= first_cover;
            prop_assert_eq!(value.ends_with(",readonly"), is_cover);
            prop_assert!(value.starts_with("type=bind,source="));
        }
    }
}

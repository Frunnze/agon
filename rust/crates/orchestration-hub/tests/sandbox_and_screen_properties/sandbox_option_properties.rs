use orchestration_core::device::SandboxKind;
use orchestration_hub::sandbox::{
    ContainerEngine, ContainerSettings, SandboxError,
    wrap_in_sandbox_keeping_input_open,
};
use proptest::prelude::*;
use proptest::sample::select;

use crate::hostile_mounts::container_options;
use crate::sandbox_mount_properties::agent_command;
use crate::sandbox_support::{
    any_hosts, any_inner_command, any_mounts, any_settings, wrap_in_container,
};

const ALLOWED_HOSTS_PREFIX: &str = "ORCHESTRATION_ALLOWED_HOSTS=";
const WHITE_SPACE: [char; 6] =
    [' ', '\t', '\n', '\u{a0}', '\u{3000}', '\u{2028}'];
const CONTROL_CHARACTERS: [char; 5] =
    ['\u{0}', '\u{7}', '\u{1b}', '\u{7f}', '\u{85}'];

fn allowed_hosts_value(arguments: &[String]) -> Option<String> {
    let assignment = arguments
        .iter()
        .find(|argument| argument.starts_with(ALLOWED_HOSTS_PREFIX))?;
    Some(assignment[ALLOWED_HOSTS_PREFIX.len()..].to_owned())
}

proptest! {
    #[test]
    fn test_engine_program_property_each_engine_runs_its_own_program(
        (settings, program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
    ) {
        let wrapped = wrap_in_container(&settings, &command, &mounts, &[])
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(wrapped.program, program);
    }

    #[test]
    fn test_engine_program_property_engine_never_changes_the_arguments(
        image in "[a-z0-9][a-z0-9./:_-]{0,29}",
        command in any_inner_command(),
        mounts in any_mounts(),
        hosts in any_hosts(),
    ) {
        let docker = ContainerSettings {
            engine: ContainerEngine::Docker,
            image: image.clone(),
        };
        let podman = ContainerSettings {
            engine: ContainerEngine::Podman,
            image,
        };

        let by_docker = wrap_in_container(&docker, &command, &mounts, &hosts);
        let by_podman = wrap_in_container(&podman, &command, &mounts, &hosts);

        let docker_arguments = by_docker.map(|wrapped| wrapped.arguments);
        let podman_arguments = by_podman.map(|wrapped| wrapped.arguments);
        prop_assert_eq!(docker_arguments, podman_arguments);
    }

    #[test]
    fn test_engine_program_property_open_input_uses_the_same_program(
        (settings, program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
    ) {
        let wrapped = wrap_in_sandbox_keeping_input_open(
            SandboxKind::Container,
            &settings,
            &command,
            &mounts,
            &[],
        )
        .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(wrapped.program, program);
    }

    #[test]
    fn test_ensure_valid_image_property_any_white_space_is_refused(
        start in "[a-z]{1,5}",
        end in "[a-z]{0,5}",
        white_space in select(WHITE_SPACE.to_vec()),
        mounts in any_mounts(),
    ) {
        let image = format!("{start}{white_space}{end}");
        let settings = ContainerSettings {
            engine: ContainerEngine::Docker,
            image: image.clone(),
        };

        let wrapped =
            wrap_in_container(&settings, &agent_command(&[]), &mounts, &[]);

        prop_assert_eq!(wrapped, Err(SandboxError::InvalidImage(image)));
    }

    #[test]
    fn test_ensure_valid_image_property_image_comes_right_after_options(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
    ) {
        let wrapped = wrap_in_container(&settings, &command, &mounts, &[])
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        let options = container_options(&wrapped, &command);
        let image_position = options.len();
        prop_assert_eq!(&wrapped.arguments[image_position], &settings.image);
        prop_assert_eq!(
            &wrapped.arguments[image_position + 1],
            &command.program,
        );
    }

    #[test]
    fn test_ensure_valid_image_property_option_like_images_are_refused(
        option in "-{1,2}[a-z]{0,8}(=[a-z/]{0,6})?",
        mounts in any_mounts(),
    ) {
        let settings = ContainerSettings {
            engine: ContainerEngine::Podman,
            image: option.clone(),
        };

        let wrapped =
            wrap_in_container(&settings, &agent_command(&[]), &mounts, &[]);

        prop_assert_eq!(wrapped, Err(SandboxError::InvalidImage(option)));
    }

    #[test]
    fn test_ensure_valid_hosts_property_hosts_round_trip_through_the_variable(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        hosts in any_hosts(),
    ) {
        let wrapped = wrap_in_container(&settings, &command, &mounts, &hosts)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        let options = container_options(&wrapped, &command);
        let value = allowed_hosts_value(options).unwrap_or_default();
        let read_back: Vec<String> = if value.is_empty() {
            Vec::new()
        } else {
            value.split(',').map(ToString::to_string).collect()
        };
        prop_assert_eq!(read_back, hosts);
    }

    #[test]
    fn test_ensure_valid_hosts_property_control_characters_are_refused(
        start in "[a-z]{0,5}",
        control in select(CONTROL_CHARACTERS.to_vec()),
        mounts in any_mounts(),
        valid_hosts in any_hosts(),
    ) {
        let host = format!("{start}{control}.example.com");
        let mut hosts = valid_hosts;
        hosts.push(host.clone());
        let settings = ContainerSettings {
            engine: ContainerEngine::Docker,
            image: "agent".to_owned(),
        };

        let wrapped =
            wrap_in_container(&settings, &agent_command(&[]), &mounts, &hosts);

        prop_assert_eq!(wrapped, Err(SandboxError::InvalidAllowedHost(host)));
    }

    #[test]
    fn test_ensure_valid_hosts_property_first_invalid_host_is_named(
        valid_hosts in any_hosts(),
        first_wrong in "[a-z]{1,4}[, ][a-z]{1,4}",
        second_wrong in "[a-z]{1,4}[, ][a-z]{1,4}",
        mounts in any_mounts(),
    ) {
        let mut hosts = valid_hosts;
        hosts.push(first_wrong.clone());
        hosts.push(second_wrong);
        let settings = ContainerSettings {
            engine: ContainerEngine::Docker,
            image: "agent".to_owned(),
        };

        let wrapped =
            wrap_in_container(&settings, &agent_command(&[]), &mounts, &hosts);

        let expected = SandboxError::InvalidAllowedHost(first_wrong);
        prop_assert_eq!(wrapped, Err(expected));
    }
}

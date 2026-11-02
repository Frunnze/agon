mod sandbox_support;

use orchestration_core::device::SandboxKind;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::sandbox::{SandboxError, wrap_in_sandbox};
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use proptest::prelude::*;
use sandbox_support::{
    any_hosts, any_inner_command, any_mounts, any_settings, wrap_in_container,
};

const CONTAINER_OPTION_FLAGS: [&str; 4] =
    ["--rm", "--mount", "--workdir", "--env"];

fn expected_mount_values(mounts: &WorkspaceMounts) -> Vec<String> {
    let mut values = vec![format!(
        "type=bind,source={},target=/workspace",
        mounts.task_folder.display(),
    )];
    for git_directory in &mounts.git_directories {
        let shown = git_directory.display();
        values.push(format!("type=bind,source={shown},target={shown}"));
    }
    values
}

fn expected_container_arguments(
    image: &str,
    command: &CommandSpecification,
    mounts: &WorkspaceMounts,
    hosts: &[String],
) -> Vec<String> {
    let mut arguments = vec!["run".to_string(), "--rm".to_string()];
    for mount in expected_mount_values(mounts) {
        arguments.push("--mount".to_string());
        arguments.push(mount);
    }
    arguments.extend([
        "--workdir".to_string(),
        "/workspace".to_string(),
        "--env".to_string(),
        format!("ORCHESTRATION_ALLOWED_HOSTS={}", hosts.join(",")),
    ]);
    for name in command.environment.keys() {
        arguments.push("--env".to_string());
        arguments.push(name.clone());
    }
    arguments.push(image.to_string());
    arguments.push(command.program.clone());
    arguments.extend(command.arguments.iter().cloned());
    arguments
}

proptest! {
    #[test]
    fn test_wrap_in_sandbox_property_container_arguments_are_exact(
        (settings, program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        hosts in any_hosts(),
    ) {
        let expected = CommandSpecification {
            program: program.to_string(),
            arguments: expected_container_arguments(
                &settings.image,
                &command,
                &mounts,
                &hosts,
            ),
            environment: command.environment.clone(),
            working_directory: None,
        };

        let wrapped = wrap_in_container(&settings, &command, &mounts, &hosts);

        prop_assert_eq!(wrapped, Ok(expected));
    }

    #[test]
    fn test_wrap_in_sandbox_property_mounts_only_task_folder_and_git(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        hosts in any_hosts(),
    ) {
        let wrapped = wrap_in_container(&settings, &command, &mounts, &hosts)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        let options_length =
            wrapped.arguments.len() - command.arguments.len() - 2;
        let options = &wrapped.arguments[..options_length];
        let mut mount_values = Vec::new();
        for (position, option) in options.iter().enumerate() {
            if option == "--mount" {
                mount_values.push(options[position + 1].clone());
            }
        }
        let flags: Vec<&String> = options
            .iter()
            .filter(|option| option.starts_with('-'))
            .collect();
        prop_assert_eq!(&options[0], "run");
        prop_assert_eq!(mount_values, expected_mount_values(&mounts));
        for flag in flags {
            prop_assert!(CONTAINER_OPTION_FLAGS.contains(&flag.as_str()));
        }
    }

    #[test]
    fn test_wrap_in_sandbox_property_local_process_runs_in_task_folder(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        hosts in any_hosts(),
    ) {
        let expected = CommandSpecification {
            working_directory: Some(mounts.task_folder.clone()),
            ..command.clone()
        };

        let wrapped = wrap_in_sandbox(
            SandboxKind::LocalProcess,
            &settings,
            &command,
            &mounts,
            &hosts,
        );

        prop_assert_eq!(wrapped, Ok(expected));
    }

    #[test]
    fn test_wrap_in_sandbox_property_micro_virtual_machine_is_rejected(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        hosts in any_hosts(),
    ) {
        let wrapped = wrap_in_sandbox(
            SandboxKind::MicroVirtualMachine,
            &settings,
            &command,
            &mounts,
            &hosts,
        );

        prop_assert_eq!(
            wrapped,
            Err(SandboxError::MicroVirtualMachineNotSupported),
        );
    }
}

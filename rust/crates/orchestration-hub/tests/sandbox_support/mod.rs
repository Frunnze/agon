use std::path::PathBuf;

use orchestration_core::device::SandboxKind;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::sandbox::{
    ContainerEngine, ContainerSettings, SandboxError, wrap_in_sandbox,
};
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use proptest::prelude::*;

pub fn any_engine() -> impl Strategy<Value = (ContainerEngine, &'static str)> {
    prop_oneof![
        Just((ContainerEngine::Docker, "docker")),
        Just((ContainerEngine::Podman, "podman")),
    ]
}

pub fn any_settings()
-> impl Strategy<Value = (ContainerSettings, &'static str)> {
    let image = "[a-z0-9][a-z0-9./:_-]{0,29}";
    (any_engine(), image).prop_map(|((engine, program), image)| {
        (ContainerSettings { engine, image }, program)
    })
}

pub fn any_folder() -> impl Strategy<Value = PathBuf> {
    "(/[a-z0-9_][a-z0-9_. -]{0,9}){1,4}".prop_map(PathBuf::from)
}

pub fn any_mounts() -> impl Strategy<Value = WorkspaceMounts> {
    let git_directory = any_folder().prop_map(|clone| clone.join(".git"));
    let git_directories = proptest::collection::vec(git_directory, 0..4);
    (any_folder(), git_directories).prop_map(
        |(task_folder, git_directories)| WorkspaceMounts {
            task_folder,
            git_directories,
        },
    )
}

pub fn any_hosts() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::vec("[a-z0-9][a-z0-9.-]{0,19}", 0..4)
}

pub fn any_inner_command() -> impl Strategy<Value = CommandSpecification> {
    let argument = prop_oneof![
        any::<String>(),
        Just("-v".to_string()),
        Just("--mount".to_string()),
        Just("--volume=/:/host".to_string()),
        Just("--privileged".to_string()),
    ];
    let arguments = proptest::collection::vec(argument, 0..6);
    let environment = proptest::collection::btree_map(
        "[A-Z_][A-Z0-9_]{0,10}",
        any::<String>(),
        0..4,
    );
    ("[a-z]{1,8}", arguments, environment).prop_map(
        |(program, arguments, environment)| CommandSpecification {
            program,
            arguments,
            environment,
            working_directory: None,
        },
    )
}

pub fn wrap_in_container(
    settings: &ContainerSettings,
    command: &CommandSpecification,
    mounts: &WorkspaceMounts,
    hosts: &[String],
) -> Result<CommandSpecification, SandboxError> {
    wrap_in_sandbox(SandboxKind::Container, settings, command, mounts, hosts)
}

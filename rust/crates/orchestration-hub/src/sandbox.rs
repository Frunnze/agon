use std::path::{Path, PathBuf};

use orchestration_core::device::SandboxKind;
use thiserror::Error;

use crate::command_specification::CommandSpecification;
use crate::safe_paths::is_plain_absolute_path;
use crate::workspace_mounts::{
    CONTAINER_WORKSPACE_DIRECTORY, GIT_DIRECTORY_NAME, WorkspaceMounts,
};

const DOCKER_PROGRAM: &str = "docker";
const PODMAN_PROGRAM: &str = "podman";
const RUN_OPTIONS: [&str; 2] = ["run", "--rm"];
const KEEP_INPUT_OPEN_OPTIONS: &[&str] = &["--interactive"];
const CLOSED_INPUT_OPTIONS: &[&str] = &[];
const MOUNT_OPTION: &str = "--mount";
const WORKING_DIRECTORY_OPTION: &str = "--workdir";
const ENVIRONMENT_OPTION: &str = "--env";
const ALLOWED_HOSTS_VARIABLE: &str = "ORCHESTRATION_ALLOWED_HOSTS";
const HOST_SEPARATOR: &str = ",";
const MOUNT_BREAKING_CHARACTERS: [char; 2] = [',', '"'];
const OPTION_PREFIX: char = '-';
const ENVIRONMENT_NAME_CONNECTOR: char = '_';

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ContainerEngine {
    Docker,
    Podman,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ContainerSettings {
    pub engine: ContainerEngine,
    pub image: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum SandboxError {
    #[error("micro virtual machine sandboxes are not supported yet")]
    MicroVirtualMachineNotSupported,
    #[error("the workspace {0:?} is not a plain absolute folder path")]
    UnsafeWorkspaceDirectory(PathBuf),
    #[error("the git folder {0:?} is not a mountable .git folder")]
    UnsafeGitDirectory(PathBuf),
    #[error("the allowed host {0:?} is not valid")]
    InvalidAllowedHost(String),
    #[error("the container image {0:?} is not valid")]
    InvalidImage(String),
    #[error("the environment variable name {0:?} is not valid")]
    InvalidEnvironmentName(String),
}

pub fn wrap_in_sandbox(
    kind: SandboxKind,
    container: &ContainerSettings,
    command: &CommandSpecification,
    mounts: &WorkspaceMounts,
    allowed_hosts: &[String],
) -> Result<CommandSpecification, SandboxError> {
    let input_options = CLOSED_INPUT_OPTIONS;
    wrap_with_input_options(
        kind,
        container,
        command,
        mounts,
        allowed_hosts,
        input_options,
    )
}

pub fn wrap_in_sandbox_keeping_input_open(
    kind: SandboxKind,
    container: &ContainerSettings,
    command: &CommandSpecification,
    mounts: &WorkspaceMounts,
    allowed_hosts: &[String],
) -> Result<CommandSpecification, SandboxError> {
    let input_options = KEEP_INPUT_OPEN_OPTIONS;
    wrap_with_input_options(
        kind,
        container,
        command,
        mounts,
        allowed_hosts,
        input_options,
    )
}

fn wrap_with_input_options(
    kind: SandboxKind,
    container: &ContainerSettings,
    command: &CommandSpecification,
    mounts: &WorkspaceMounts,
    allowed_hosts: &[String],
    input_options: &[&str],
) -> Result<CommandSpecification, SandboxError> {
    if !is_plain_absolute_path(&mounts.task_folder) {
        let task_folder = mounts.task_folder.clone();
        return Err(SandboxError::UnsafeWorkspaceDirectory(task_folder));
    }

    match kind {
        SandboxKind::LocalProcess => Ok(CommandSpecification {
            working_directory: Some(mounts.task_folder.clone()),
            ..command.clone()
        }),
        SandboxKind::Container => wrap_in_container(
            container,
            command,
            mounts,
            allowed_hosts,
            input_options,
        ),
        SandboxKind::MicroVirtualMachine => {
            Err(SandboxError::MicroVirtualMachineNotSupported)
        }
    }
}

fn wrap_in_container(
    container: &ContainerSettings,
    command: &CommandSpecification,
    mounts: &WorkspaceMounts,
    allowed_hosts: &[String],
    input_options: &[&str],
) -> Result<CommandSpecification, SandboxError> {
    ensure_mountable_task_folder(&mounts.task_folder)?;
    ensure_mountable_git_directories(&mounts.git_directories)?;
    ensure_valid_image(&container.image)?;
    ensure_valid_hosts(allowed_hosts)?;
    ensure_valid_environment_names(command)?;

    let mut arguments: Vec<String> =
        RUN_OPTIONS.iter().map(ToString::to_string).collect();
    for mount in describe_mounts(mounts) {
        arguments.push(MOUNT_OPTION.to_string());
        arguments.push(mount);
    }

    let allowed_hosts_assignment = format!(
        "{ALLOWED_HOSTS_VARIABLE}={}",
        allowed_hosts.join(HOST_SEPARATOR)
    );
    arguments.extend([
        WORKING_DIRECTORY_OPTION.to_string(),
        CONTAINER_WORKSPACE_DIRECTORY.to_string(),
        ENVIRONMENT_OPTION.to_string(),
        allowed_hosts_assignment,
    ]);
    for name in command.environment.keys() {
        arguments.push(ENVIRONMENT_OPTION.to_string());
        arguments.push(name.clone());
    }
    arguments.extend(input_options.iter().map(ToString::to_string));
    arguments.push(container.image.clone());
    arguments.push(command.program.clone());
    arguments.extend(command.arguments.iter().cloned());

    Ok(CommandSpecification {
        program: engine_program(container.engine).to_string(),
        arguments,
        environment: command.environment.clone(),
        working_directory: None,
    })
}

fn describe_mounts(mounts: &WorkspaceMounts) -> Vec<String> {
    let task_folder = mounts.task_folder.display().to_string();
    let mut descriptions =
        vec![bind_mount(&task_folder, CONTAINER_WORKSPACE_DIRECTORY)];
    for git_directory in &mounts.git_directories {
        let shown = git_directory.display().to_string();
        descriptions.push(bind_mount(&shown, &shown));
    }
    descriptions
}

fn bind_mount(source: &str, target: &str) -> String {
    format!("type=bind,source={source},target={target}")
}

fn breaks_mount_syntax(path: &Path) -> bool {
    path.display()
        .to_string()
        .contains(MOUNT_BREAKING_CHARACTERS)
}

fn ensure_mountable_task_folder(
    task_folder: &Path,
) -> Result<(), SandboxError> {
    if breaks_mount_syntax(task_folder) {
        let task_folder = task_folder.to_path_buf();
        return Err(SandboxError::UnsafeWorkspaceDirectory(task_folder));
    }
    Ok(())
}

fn ensure_mountable_git_directories(
    git_directories: &[PathBuf],
) -> Result<(), SandboxError> {
    for git_directory in git_directories {
        let is_git_folder = git_directory
            .file_name()
            .is_some_and(|name| name == GIT_DIRECTORY_NAME);
        let is_mountable = is_plain_absolute_path(git_directory)
            && is_git_folder
            && !breaks_mount_syntax(git_directory);
        if !is_mountable {
            let git_directory = git_directory.clone();
            return Err(SandboxError::UnsafeGitDirectory(git_directory));
        }
    }
    Ok(())
}

fn engine_program(engine: ContainerEngine) -> &'static str {
    match engine {
        ContainerEngine::Docker => DOCKER_PROGRAM,
        ContainerEngine::Podman => PODMAN_PROGRAM,
    }
}

fn ensure_valid_image(image: &str) -> Result<(), SandboxError> {
    let is_valid = !image.is_empty()
        && !image.starts_with(OPTION_PREFIX)
        && !image.chars().any(char::is_whitespace);
    if !is_valid {
        return Err(SandboxError::InvalidImage(image.to_string()));
    }
    Ok(())
}

fn ensure_valid_hosts(allowed_hosts: &[String]) -> Result<(), SandboxError> {
    for host in allowed_hosts {
        let is_valid = !host.is_empty()
            && !host.contains(HOST_SEPARATOR)
            && !host.chars().any(|character| {
                character.is_whitespace() || character.is_control()
            });
        if !is_valid {
            return Err(SandboxError::InvalidAllowedHost(host.clone()));
        }
    }
    Ok(())
}

fn ensure_valid_environment_names(
    command: &CommandSpecification,
) -> Result<(), SandboxError> {
    for name in command.environment.keys() {
        if !is_valid_environment_name(name) {
            return Err(SandboxError::InvalidEnvironmentName(name.clone()));
        }
    }
    Ok(())
}

fn is_valid_environment_name(name: &str) -> bool {
    let has_valid_first_character = name.chars().next().is_some_and(|first| {
        first.is_ascii_alphabetic() || first == ENVIRONMENT_NAME_CONNECTOR
    });
    let has_only_name_characters = name.chars().all(|character| {
        character.is_ascii_alphanumeric()
            || character == ENVIRONMENT_NAME_CONNECTOR
    });
    has_valid_first_character && has_only_name_characters
}

use std::path::PathBuf;

use orchestration_core::device::SandboxKind;

pub const CONTAINER_WORKSPACE_DIRECTORY: &str = "/workspace";
pub const GIT_DIRECTORY_NAME: &str = ".git";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct WorkspaceMounts {
    pub task_folder: PathBuf,
    pub git_directories: Vec<PathBuf>,
}

#[must_use]
pub fn locate_task_folder_seen_by_agent(
    sandbox: SandboxKind,
    mounts: &WorkspaceMounts,
) -> PathBuf {
    match sandbox {
        SandboxKind::LocalProcess => mounts.task_folder.clone(),
        SandboxKind::Container | SandboxKind::MicroVirtualMachine => {
            PathBuf::from(CONTAINER_WORKSPACE_DIRECTORY)
        }
    }
}

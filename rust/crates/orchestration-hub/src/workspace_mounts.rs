use std::path::PathBuf;

pub const CONTAINER_WORKSPACE_DIRECTORY: &str = "/workspace";
pub const GIT_DIRECTORY_NAME: &str = ".git";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct WorkspaceMounts {
    pub task_folder: PathBuf,
    pub git_directories: Vec<PathBuf>,
}

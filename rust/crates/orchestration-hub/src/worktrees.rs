use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;

use thiserror::Error;

use crate::cached_clones::record_clone_address;
use crate::clone_locks::{CloneLocks, hold_lock};
use crate::command_specification::CommandSpecification;
use crate::workspace_mounts::{GIT_DIRECTORY_NAME, WorkspaceMounts};
use crate::worktree_commands::{
    list_task_branches_command, prune_worktrees_command,
};
use crate::worktree_plan::{RepositoryWorktreePlan, WorktreePlan};

const ARGUMENT_SEPARATOR: &str = " ";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WorktreeOrigin {
    Created,
    Reused,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PreparedWorktree {
    pub path: PathBuf,
    pub origin: WorktreeOrigin,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PreparedWorkspace {
    pub mounts: WorkspaceMounts,
    pub worktrees: Vec<PreparedWorktree>,
}

#[derive(Debug, Error)]
pub enum WorktreeError {
    #[error("could not change the folder {path:?}: {source}")]
    ChangeFolder {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
    #[error("could not resolve the folder {path:?}: {source}")]
    ResolveFolder {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
    #[error("could not read the folder {path:?}: {source}")]
    ReadFolder {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
    #[error("the folder {0:?} is taken by a file or a link, not a folder")]
    BlockedFolder(PathBuf),
    #[error("could not start git: {0}")]
    StartGit(#[source] io::Error),
    #[error("git {arguments} failed: {output}")]
    GitFailed { arguments: String, output: String },
}

pub fn create_worktrees(
    plan: &WorktreePlan,
    clone_locks: &CloneLocks,
) -> Result<PreparedWorkspace, WorktreeError> {
    ensure_not_blocked(&plan.task_folder)?;
    fs::create_dir_all(&plan.task_folder).map_err(|source| {
        WorktreeError::ChangeFolder {
            path: plan.task_folder.clone(),
            source,
        }
    })?;

    let mut worktrees = Vec::new();
    let mut git_directories = Vec::new();
    for repository in &plan.repositories {
        let origin = prepare_repository_worktree(
            repository,
            &plan.branch,
            clone_locks,
        )?;
        worktrees.push(PreparedWorktree {
            path: repository.worktree.clone(),
            origin,
        });
        let git_directory = repository.cached_clone.join(GIT_DIRECTORY_NAME);
        git_directories.push(resolve_folder(&git_directory)?);
    }

    let mounts = WorkspaceMounts {
        task_folder: resolve_folder(&plan.task_folder)?,
        git_directories,
        placeholder_mounts: Vec::new(),
    };
    Ok(PreparedWorkspace { mounts, worktrees })
}

pub fn remove_worktrees(
    plan: &WorktreePlan,
    clone_locks: &CloneLocks,
) -> Result<(), WorktreeError> {
    for repository in &plan.repositories {
        let clone_lock = clone_locks.lock_for(&repository.cached_clone);
        let _exclusive_clone_access = hold_lock(&clone_lock);
        if is_git_checkout(&repository.worktree) {
            run_git(&repository.remove_worktree_command)?;
        }
    }

    if plan.task_folder.exists() {
        fs::remove_dir_all(&plan.task_folder).map_err(|source| {
            WorktreeError::ChangeFolder {
                path: plan.task_folder.clone(),
                source,
            }
        })?;
    }
    Ok(())
}

pub fn delete_task_branches(
    plan: &WorktreePlan,
    clone_locks: &CloneLocks,
) -> Result<(), WorktreeError> {
    for repository in &plan.repositories {
        let clone_lock = clone_locks.lock_for(&repository.cached_clone);
        let _exclusive_clone_access = hold_lock(&clone_lock);
        run_git(&repository.delete_branch_command)?;
    }
    Ok(())
}

fn prepare_repository_worktree(
    repository: &RepositoryWorktreePlan,
    branch: &str,
    clone_locks: &CloneLocks,
) -> Result<WorktreeOrigin, WorktreeError> {
    let clone_lock = clone_locks.lock_for(&repository.cached_clone);
    let _exclusive_clone_access = hold_lock(&clone_lock);
    ensure_not_blocked(&repository.worktree)?;
    if is_git_checkout(&repository.worktree) {
        return Ok(WorktreeOrigin::Reused);
    }

    if is_git_checkout(&repository.cached_clone) {
        run_git(&repository.fetch_command)?;
    } else {
        run_git(&repository.clone_command)?;
    }
    let recording =
        record_clone_address(&repository.cached_clone, &repository.address);
    if let Err(source) = recording {
        let path = repository.cached_clone.clone();
        return Err(WorktreeError::ChangeFolder { path, source });
    }
    add_task_worktree(repository, branch)?;
    Ok(WorktreeOrigin::Created)
}

fn add_task_worktree(
    repository: &RepositoryWorktreePlan,
    branch: &str,
) -> Result<(), WorktreeError> {
    let cached_clone = &repository.cached_clone;
    run_git(&prune_worktrees_command(cached_clone))?;

    let task_branches =
        read_git_output(&list_task_branches_command(cached_clone))?;
    let is_branch_kept = task_branches.lines().any(|listed| listed == branch);
    if is_branch_kept {
        return run_git(&repository.add_kept_branch_worktree_command);
    }
    run_git(&repository.add_worktree_command)
}

fn ensure_not_blocked(folder: &Path) -> Result<(), WorktreeError> {
    let metadata = match fs::symlink_metadata(folder) {
        Ok(metadata) => metadata,
        Err(problem) if problem.kind() == io::ErrorKind::NotFound => {
            return Ok(());
        }
        Err(source) => {
            let path = folder.to_path_buf();
            return Err(WorktreeError::ResolveFolder { path, source });
        }
    };

    if !metadata.is_dir() {
        return Err(WorktreeError::BlockedFolder(folder.to_path_buf()));
    }
    Ok(())
}

fn is_git_checkout(directory: &Path) -> bool {
    directory.join(GIT_DIRECTORY_NAME).exists()
}

fn resolve_folder(folder: &Path) -> Result<PathBuf, WorktreeError> {
    folder
        .canonicalize()
        .map_err(|source| WorktreeError::ResolveFolder {
            path: folder.to_path_buf(),
            source,
        })
}

pub(crate) fn run_git(
    command: &CommandSpecification,
) -> Result<(), WorktreeError> {
    read_git_output(command)?;
    Ok(())
}

pub(crate) fn read_git_output(
    command: &CommandSpecification,
) -> Result<String, WorktreeError> {
    let mut git = Command::new(&command.program);
    git.args(&command.arguments).envs(&command.environment);
    if let Some(directory) = &command.working_directory {
        git.current_dir(directory);
    }

    let output = git.output().map_err(WorktreeError::StartGit)?;
    if output.status.success() {
        return Ok(String::from_utf8_lossy(&output.stdout).into_owned());
    }
    Err(WorktreeError::GitFailed {
        arguments: command.arguments.join(ARGUMENT_SEPARATOR),
        output: String::from_utf8_lossy(&output.stderr).trim().to_string(),
    })
}

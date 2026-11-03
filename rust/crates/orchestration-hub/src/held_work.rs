use std::collections::BTreeSet;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use orchestration_core::identifiers::TaskId;

use crate::branch_names::TASK_BRANCH_PREFIX;
use crate::cached_clones::{cached_clone_folder, list_cached_repositories};
use crate::folder_removal::is_real_folder;
use crate::task_folder_names::read_task_id;
use crate::worktree_commands::list_task_branches_command;
use crate::worktree_roots::WorktreeRoots;
use crate::worktrees::{WorktreeError, read_git_output};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TaskFolder {
    pub folder: PathBuf,
    pub task_id: TaskId,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TaskBranch {
    pub cached_clone: PathBuf,
    pub branch: String,
    pub task_id: TaskId,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct HeldWork {
    pub task_folders: Vec<TaskFolder>,
    pub task_branches: Vec<TaskBranch>,
}

impl HeldWork {
    #[must_use]
    pub fn list_task_ids(&self) -> BTreeSet<TaskId> {
        let mut task_ids = BTreeSet::new();
        for task_folder in &self.task_folders {
            task_ids.insert(task_folder.task_id);
        }
        for task_branch in &self.task_branches {
            task_ids.insert(task_branch.task_id);
        }
        task_ids
    }
}

pub fn list_held_work(
    roots: &WorktreeRoots,
) -> Result<HeldWork, WorktreeError> {
    Ok(HeldWork {
        task_folders: list_task_folders(&roots.worktrees_root)?,
        task_branches: list_task_branches(&roots.cache_root)?,
    })
}

pub(crate) fn list_real_clones(
    cache_root: &Path,
) -> Result<Vec<(String, PathBuf)>, WorktreeError> {
    let addresses = list_cached_repositories(cache_root)
        .map_err(|source| read_folder_error(cache_root, source))?;
    let mut clones = Vec::new();
    for address in addresses {
        let cached_clone = cached_clone_folder(cache_root, &address);
        if is_real_folder(&cached_clone) {
            clones.push((address, cached_clone));
        }
    }
    Ok(clones)
}

fn list_task_folders(
    worktrees_root: &Path,
) -> Result<Vec<TaskFolder>, WorktreeError> {
    let folder_entries = match fs::read_dir(worktrees_root) {
        Ok(folder_entries) => folder_entries,
        Err(problem) if problem.kind() == io::ErrorKind::NotFound => {
            return Ok(Vec::new());
        }
        Err(source) => return Err(read_folder_error(worktrees_root, source)),
    };

    let mut task_folders = Vec::new();
    for folder_entry in folder_entries {
        let folder_entry = folder_entry
            .map_err(|source| read_folder_error(worktrees_root, source))?;
        let folder = folder_entry.path();
        let task_id = folder_entry.file_name().to_str().and_then(read_task_id);
        if let (true, Some(task_id)) = (is_real_folder(&folder), task_id) {
            task_folders.push(TaskFolder { folder, task_id });
        }
    }
    Ok(task_folders)
}

fn list_task_branches(
    cache_root: &Path,
) -> Result<Vec<TaskBranch>, WorktreeError> {
    let mut task_branches = Vec::new();
    for (_address, cached_clone) in list_real_clones(cache_root)? {
        let command = list_task_branches_command(&cached_clone);
        let listing = read_git_output(&command)?;
        for branch in listing.lines() {
            let task_id = branch
                .strip_prefix(TASK_BRANCH_PREFIX)
                .and_then(read_task_id);
            if let Some(task_id) = task_id {
                task_branches.push(TaskBranch {
                    cached_clone: cached_clone.clone(),
                    branch: branch.to_owned(),
                    task_id,
                });
            }
        }
    }
    Ok(task_branches)
}

fn read_folder_error(folder: &Path, source: io::Error) -> WorktreeError {
    WorktreeError::ReadFolder {
        path: folder.to_path_buf(),
        source,
    }
}

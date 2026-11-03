use std::collections::BTreeSet;
use std::path::{Path, PathBuf};

use orchestration_core::identifiers::TaskId;

use crate::folder_removal::{is_real_folder, remove_folder};
use crate::held_work::{HeldWork, list_real_clones};
use crate::worktree_commands::{
    delete_branch_command, list_worktrees_command, prune_worktrees_command,
};
use crate::worktree_roots::WorktreeRoots;
use crate::worktrees::{WorktreeError, read_git_output, run_git};

const WORKTREE_LINE_PREFIX: &str = "worktree ";

pub fn remove_forgotten_tasks(
    held_work: &HeldWork,
    forgotten_tasks: &BTreeSet<TaskId>,
) -> Result<(), WorktreeError> {
    for task_folder in &held_work.task_folders {
        if forgotten_tasks.contains(&task_folder.task_id) {
            remove_folder(&task_folder.folder)?;
        }
    }

    let mut forgotten_branches = Vec::new();
    let mut touched_clones = BTreeSet::new();
    for task_branch in &held_work.task_branches {
        if forgotten_tasks.contains(&task_branch.task_id) {
            forgotten_branches.push(task_branch);
            touched_clones.insert(task_branch.cached_clone.clone());
        }
    }
    for cached_clone in &touched_clones {
        run_git(&prune_worktrees_command(cached_clone))?;
    }
    for task_branch in forgotten_branches {
        let cached_clone = &task_branch.cached_clone;
        run_git(&delete_branch_command(cached_clone, &task_branch.branch))?;
    }
    Ok(())
}

pub fn remove_unused_clones(
    roots: &WorktreeRoots,
    unused_addresses: &[String],
) -> Result<(), WorktreeError> {
    for (address, cached_clone) in list_real_clones(&roots.cache_root)? {
        if !unused_addresses.contains(&address) {
            continue;
        }
        for worktree in list_linked_worktrees(&cached_clone)? {
            if is_inside_folder(&worktree, &roots.worktrees_root) {
                remove_folder(&worktree)?;
            }
        }
        remove_folder(&cached_clone)?;
    }
    Ok(())
}

fn list_linked_worktrees(
    cached_clone: &Path,
) -> Result<Vec<PathBuf>, WorktreeError> {
    let listing = read_git_output(&list_worktrees_command(cached_clone))?;
    let mut worktrees = Vec::new();
    for line in listing.lines() {
        if let Some(path) = line.strip_prefix(WORKTREE_LINE_PREFIX) {
            worktrees.push(PathBuf::from(path));
        }
    }
    Ok(worktrees)
}

fn is_inside_folder(path: &Path, folder: &Path) -> bool {
    let (Ok(real_path), Ok(real_folder)) =
        (path.canonicalize(), folder.canonicalize())
    else {
        return false;
    };
    let is_below =
        real_path.starts_with(&real_folder) && real_path != real_folder;
    is_below && is_real_folder(path)
}

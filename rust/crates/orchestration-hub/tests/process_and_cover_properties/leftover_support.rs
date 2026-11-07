use std::fs;
use std::path::{Path, PathBuf};

use orchestration_core::identifiers::TaskId;
use orchestration_hub::cached_clones::list_cached_repositories;
use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreePlan};
use orchestration_hub::worktree_roots::WorktreeRoots;
use orchestration_hub::worktrees::create_worktrees;
use proptest::prelude::*;

use crate::git_support::{
    RunnerFolders, create_origin, numbered_task_id, plan_for, run_git,
};
use crate::target_folders::{create_target_folder, fail_with};

pub const ORIGIN_NAMES: [&str; 2] = ["app", "site"];
pub const UNCOMMITTED_FILE: &str = "notes.txt";
const CACHE_FOLDER_NAME: &str = "cache";
const WORKTREES_FOLDER_NAME: &str = "worktrees";
const FIRST_TASK_NUMBER: u128 = 0x7100;

pub struct PlannedTask {
    pub task_id: TaskId,
    pub plan: WorktreePlan,
}

pub fn prepare_target_runner_folders() -> Result<RunnerFolders, TestCaseError>
{
    let temporary = create_target_folder()?;
    Ok(RunnerFolders {
        cache_root: temporary.path().join(CACHE_FOLDER_NAME),
        worktrees_root: temporary.path().join(WORKTREES_FOLDER_NAME),
        temporary,
    })
}

pub fn roots_of(folders: &RunnerFolders) -> WorktreeRoots {
    WorktreeRoots {
        cache_root: folders.cache_root.clone(),
        worktrees_root: folders.worktrees_root.clone(),
    }
}

pub fn create_origins(
    folders: &RunnerFolders,
) -> Result<Vec<PathBuf>, TestCaseError> {
    let mut origins = Vec::new();
    for name in ORIGIN_NAMES {
        origins.push(
            create_origin(folders, name)
                .map_err(|problem| fail_with(&problem))?,
        );
    }
    Ok(origins)
}

pub fn create_tasks(
    folders: &RunnerFolders,
    origins: &[PathBuf],
    task_count: usize,
) -> Result<Vec<PlannedTask>, TestCaseError> {
    let clone_locks = CloneLocks::default();
    let mut planned_tasks = Vec::new();
    for position in 0..task_count {
        let offset =
            u128::try_from(position).map_err(|problem| fail_with(&problem))?;
        let task_id = numbered_task_id(FIRST_TASK_NUMBER + offset)
            .map_err(|problem| fail_with(&problem))?;
        let title = format!("Leftover task {position}");
        let plan = plan_for(
            folders,
            task_id,
            &title,
            WorktreeLifetime::PerTask,
            origins,
        )
        .map_err(|problem| fail_with(&problem))?;
        create_worktrees(&plan, &clone_locks)
            .map_err(|problem| fail_with(&problem))?;
        for repository in &plan.repositories {
            fs::write(repository.worktree.join(UNCOMMITTED_FILE), "work")
                .map_err(|problem| fail_with(&problem))?;
        }
        planned_tasks.push(PlannedTask { task_id, plan });
    }
    Ok(planned_tasks)
}

pub fn add_detached_worktree(
    cached_clone: &Path,
    worktree: &Path,
) -> Result<(), TestCaseError> {
    let worktree_text = worktree.display().to_string();
    run_git(
        cached_clone,
        &["worktree", "add", "--detach", &worktree_text],
    )
    .map_err(|problem| fail_with(&problem))?;
    Ok(())
}

pub fn list_addresses(
    cache_root: &Path,
) -> Result<Vec<String>, TestCaseError> {
    list_cached_repositories(cache_root).map_err(|problem| fail_with(&problem))
}

pub fn first_clone_of(
    planned_tasks: &[PlannedTask],
) -> Result<PathBuf, TestCaseError> {
    let planned = planned_tasks
        .first()
        .ok_or_else(|| TestCaseError::fail("no task was planned"))?;
    Ok(planned.plan.repositories[0].cached_clone.clone())
}

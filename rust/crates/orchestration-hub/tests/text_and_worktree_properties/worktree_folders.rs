use std::path::{Path, PathBuf};

use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreePlan};
use orchestration_hub::worktrees::{PreparedWorkspace, create_worktrees};
use proptest::prelude::*;

use crate::git_support::{
    RunnerFolders, create_origin, numbered_task_id, plan_for, run_git,
};
use crate::held_folders::{create_held_folders, to_case_error};

pub type CaseResult<T> = Result<T, TestCaseError>;

pub const GIT_CASES: u32 = 6;
pub const REPOSITORY_NAMES: [&str; 3] = ["app", "api", "docs"];

pub fn prepare_folders() -> CaseResult<RunnerFolders> {
    let held = create_held_folders().map_err(to_case_error)?;
    Ok(RunnerFolders {
        temporary: held.temporary,
        cache_root: held.roots.cache_root,
        worktrees_root: held.roots.worktrees_root,
    })
}

pub fn create_origins(
    folders: &RunnerFolders,
    count: usize,
) -> CaseResult<Vec<PathBuf>> {
    let mut origins = Vec::new();
    for name in REPOSITORY_NAMES.iter().take(count) {
        origins.push(create_origin(folders, name).map_err(to_case_error)?);
    }
    Ok(origins)
}

pub fn plan_task(
    folders: &RunnerFolders,
    task_number: u128,
    title: &str,
    lifetime: WorktreeLifetime,
    origins: &[PathBuf],
) -> CaseResult<WorktreePlan> {
    let task_id = numbered_task_id(task_number).map_err(to_case_error)?;
    plan_for(folders, task_id, title, lifetime, origins).map_err(to_case_error)
}

pub fn create(plan: &WorktreePlan) -> CaseResult<PreparedWorkspace> {
    create_worktrees(plan, &CloneLocks::default()).map_err(to_case_error)
}

pub fn git(directory: &Path, arguments: &[&str]) -> CaseResult<String> {
    run_git(directory, arguments).map_err(to_case_error)
}

pub fn branch_exists(clone: &Path, branch: &str) -> CaseResult<bool> {
    let reference = format!("refs/heads/{branch}");
    let format = "--format=%(refname)";
    let listing = git(clone, &["for-each-ref", format, &reference])?;
    Ok(listing == reference)
}

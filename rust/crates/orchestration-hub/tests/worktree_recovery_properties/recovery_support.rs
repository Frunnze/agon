use std::fs;
use std::path::Path;

use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::worktree_plan::WorktreePlan;
use orchestration_hub::worktrees::{PreparedWorkspace, create_worktrees};

use crate::git_support::commit_file;
use crate::held_folders::to_case_error;
use crate::worktree_folders::{CaseResult, git};

pub type CreationAttempt = Result<PreparedWorkspace, String>;

pub const RECOVERED_TASK: u128 = 0x5151_0000_0000_4000_8000_0000_0000_0051;
pub const NEIGHBOUR_TASK: u128 = 0x6262_0000_0000_4000_8000_0000_0000_0062;
pub const WORK_FILE_NAME: &str = "work.txt";

pub fn commit_work(
    worktree: &Path,
    file_name: &str,
    note: &str,
) -> CaseResult<String> {
    commit_file(worktree, file_name, note).map_err(to_case_error)?;
    git(worktree, &["rev-parse", "HEAD"])
}

pub fn delete_by_hand(folder: &Path) -> CaseResult<()> {
    fs::remove_dir_all(folder).map_err(to_case_error)
}

pub fn read_text(path: &Path) -> CaseResult<String> {
    fs::read_to_string(path).map_err(to_case_error)
}

pub fn branch_commit(plan: &WorktreePlan, index: usize) -> CaseResult<String> {
    let cached_clone = &plan.repositories[index].cached_clone;
    git(cached_clone, &["rev-parse", &plan.branch])
}

pub fn checked_out_branch(worktree: &Path) -> CaseResult<String> {
    git(worktree, &["symbolic-ref", "--short", "HEAD"])
}

pub fn head_commit(worktree: &Path) -> CaseResult<String> {
    git(worktree, &["rev-parse", "HEAD"])
}

pub fn try_create(plan: &WorktreePlan) -> CreationAttempt {
    let creation = create_worktrees(plan, &CloneLocks::default());
    creation.map_err(|problem| problem.to_string())
}

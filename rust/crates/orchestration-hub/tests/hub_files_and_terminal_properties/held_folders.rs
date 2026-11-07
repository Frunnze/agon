use std::error::Error;
use std::fmt::Display;
use std::fs;
use std::path::{Path, PathBuf};

use orchestration_core::identifiers::TaskId;
use orchestration_hub::cached_clones::cached_clone_folder;
use orchestration_hub::worktree_roots::WorktreeRoots;
use proptest::prelude::*;
use tempfile::TempDir;
use uuid::Uuid;

use crate::git_support::run_git;

pub type FolderResult<T> = Result<T, Box<dyn Error>>;

pub const TASK_BRANCH_PREFIX: &str = "task/";

const TARGET_TEMPORARY_FOLDER: &str = env!("CARGO_TARGET_TMPDIR");
const TEMPORARY_FOLDER_PREFIX: &str = "hub-held-work-";
const CACHE_FOLDER_NAME: &str = "cache";
const WORKTREES_FOLDER_NAME: &str = "worktrees";
const NOTE_FILE_NAME: &str = "notes.txt";
const FIRST_COMMIT_MESSAGE: &str = "Start";

#[derive(Debug)]
pub struct HeldFolders {
    pub temporary: TempDir,
    pub roots: WorktreeRoots,
}

pub fn to_case_error(problem: impl Display) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

pub fn create_held_folders() -> FolderResult<HeldFolders> {
    let temporary = tempfile::Builder::new()
        .prefix(TEMPORARY_FOLDER_PREFIX)
        .tempdir_in(TARGET_TEMPORARY_FOLDER)?;
    let roots = WorktreeRoots {
        cache_root: temporary.path().join(CACHE_FOLDER_NAME),
        worktrees_root: temporary.path().join(WORKTREES_FOLDER_NAME),
    };
    Ok(HeldFolders { temporary, roots })
}

pub fn any_task_id() -> impl Strategy<Value = TaskId> {
    any::<u128>().prop_map(|number| TaskId(Uuid::from_u128(number)))
}

pub fn task_folder_name(slug: &str, task_id: TaskId) -> String {
    format!("{slug}-{}", task_id.0.simple())
}

pub fn create_task_folder(
    worktrees_root: &Path,
    folder_name: &str,
) -> FolderResult<PathBuf> {
    let folder = worktrees_root.join(folder_name);
    fs::create_dir_all(folder.join("app"))?;
    fs::write(folder.join("app").join(NOTE_FILE_NAME), "work in progress")?;
    Ok(folder)
}

pub fn create_cached_clone(
    cache_root: &Path,
    address: &str,
    branches: &[String],
) -> FolderResult<PathBuf> {
    let clone = cached_clone_folder(cache_root, address);
    fs::create_dir_all(&clone)?;
    run_git(&clone, &["init", "--quiet", "--initial-branch=main"])?;
    run_git(
        &clone,
        &[
            "commit",
            "--quiet",
            "--allow-empty",
            "-m",
            FIRST_COMMIT_MESSAGE,
        ],
    )?;
    for branch in branches {
        run_git(&clone, &["branch", branch])?;
    }
    Ok(clone)
}

pub fn any_slug() -> impl Strategy<Value = String> {
    "[a-z][a-z0-9]{0,8}"
}

pub fn any_address() -> impl Strategy<Value = String> {
    "[a-z]{1,6}\\.test/[a-z]{1,6}/[a-z]{1,8}"
}

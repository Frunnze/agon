use std::fs;
use std::os::unix::fs::symlink;
use std::path::Path;

use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::repository_reading::RepositoryReader;
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreePlan};
use orchestration_hub::worktrees::create_worktrees;

use crate::git_support::{
    RunnerFolders, TestResult, create_origin, numbered_task_id, plan_for,
    prepare_runner_folders, run_git,
};

const TASK_NUMBER: u128 = 0x5c18_0000_0000_4000_8000_0000_0000_9e07;
const TASK_TITLE: &str = "Fix login redirect";
pub const REDIRECT_SOURCE: &str = "export const HOME_PATH = \"/\";\n";
pub const TASK_ONLY_SOURCE: &str = "export const fixed = true;\n";
const TINY_PNG: [u8; 33] = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48,
    0x44, 0x52, 0, 0, 0, 2, 0, 0, 0, 3, 8, 6, 0, 0, 0, 0x1C, 0x2F, 0x3F, 0x5B,
];
const MEBIBYTE: usize = 1024 * 1024;
const HUGE_FILE_MEBIBYTES: usize = 6;

pub struct RepositoryFixture {
    pub _folders: RunnerFolders,
    pub plan: WorktreePlan,
    pub reader: RepositoryReader,
}

impl RepositoryFixture {
    pub fn task_branch(&self) -> &str {
        &self.plan.branch
    }
}

fn write_file(root: &Path, path: &str, content: &[u8]) -> TestResult<()> {
    let target = root.join(path);
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(target, content)?;
    Ok(())
}

fn fill_origin(origin: &Path) -> TestResult<()> {
    write_file(origin, "src/auth/redirect.ts", REDIRECT_SOURCE.as_bytes())?;
    write_file(origin, "assets/icon.png", &TINY_PNG)?;
    write_file(origin, "assets/data.bin", &[1, 0, 2, 0, 3])?;
    let large_text = vec![b'a'; MEBIBYTE + 1];
    write_file(origin, "notes/large.txt", &large_text)?;
    let huge = vec![7; HUGE_FILE_MEBIBYTES * MEBIBYTE];
    write_file(origin, "assets/onboarding.mp4", &huge)?;
    symlink("../../../../../etc/passwd", origin.join("outside"))?;
    symlink("src", origin.join("source-link"))?;
    run_git(origin, &["add", "--all"])?;
    run_git(origin, &["commit", "--message", "Fill the repository"])?;
    run_git(origin, &["branch", "release"])?;
    Ok(())
}

fn commit_on_task_branch(worktree: &Path) -> TestResult<()> {
    write_file(worktree, "src/auth/fix.ts", TASK_ONLY_SOURCE.as_bytes())?;
    run_git(worktree, &["add", "--all"])?;
    run_git(worktree, &["commit", "--message", "Fix the redirect"])?;
    Ok(())
}

pub fn build_fixture() -> TestResult<RepositoryFixture> {
    let folders = prepare_runner_folders()?;
    let origin = create_origin(&folders, "app")?;
    fill_origin(&origin)?;
    let task_id = numbered_task_id(TASK_NUMBER)?;
    let lifetime = WorktreeLifetime::PerTask;
    let plan = plan_for(&folders, task_id, TASK_TITLE, lifetime, &[origin])?;
    create_worktrees(&plan, &CloneLocks::default())?;
    let repository = plan.repositories.first().ok_or("no repository")?;
    commit_on_task_branch(&repository.worktree)?;
    let reader = RepositoryReader::open(&repository.cached_clone)?;
    Ok(RepositoryFixture {
        _folders: folders,
        plan,
        reader,
    })
}

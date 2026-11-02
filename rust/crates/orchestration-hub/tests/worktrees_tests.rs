mod git_support;

use std::fs;
use std::path::{Path, PathBuf};

use git_support::{
    RunnerFolders, TestResult, commit_file, create_origin, numbered_task_id,
    plan_for, prepare_runner_folders, run_git,
};
use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreePlan};
use orchestration_hub::worktrees::{
    WorktreeOrigin, create_worktrees, delete_task_branches, remove_worktrees,
};

const TASK_NUMBER: u128 = 0x67e5_5044_10b1_426f_9247_bb68_0e5f_e0c8;

fn plan_task(
    folders: &RunnerFolders,
    origin: &Path,
    title: &str,
    lifetime: WorktreeLifetime,
) -> TestResult<WorktreePlan> {
    let task_id = numbered_task_id(TASK_NUMBER)?;
    plan_for(folders, task_id, title, lifetime, &[origin.to_path_buf()])
}

fn first_worktree(plan: &WorktreePlan) -> TestResult<PathBuf> {
    let repository = plan.repositories.first().ok_or("no repository")?;
    Ok(repository.worktree.clone())
}

fn first_cached_clone(plan: &WorktreePlan) -> TestResult<PathBuf> {
    let repository = plan.repositories.first().ok_or("no repository")?;
    Ok(repository.cached_clone.clone())
}

fn checked_out_branch(worktree: &Path) -> TestResult<String> {
    run_git(worktree, &["rev-parse", "--abbrev-ref", "HEAD"])
}

fn branch_exists(clone: &Path, branch: &str) -> bool {
    let reference = format!("refs/heads/{branch}");
    run_git(clone, &["rev-parse", "--verify", "--quiet", &reference]).is_ok()
}

#[test]
fn creates_a_task_worktree_and_reuses_it_on_retry() -> TestResult<()> {
    let folders = prepare_runner_folders()?;
    let origin = create_origin(&folders, "app")?;
    let clone_locks = CloneLocks::default();
    let lifetime = WorktreeLifetime::PerTask;
    let plan = plan_task(&folders, &origin, "Fix the login bug", lifetime)?;
    let worktree = first_worktree(&plan)?;

    let created = create_worktrees(&plan, &clone_locks)?;
    fs::write(worktree.join("notes.txt"), "work in progress")?;
    let retried = create_worktrees(&plan, &clone_locks)?;

    let real_task_folder = plan.task_folder.canonicalize()?;
    assert_eq!(created.mounts.task_folder, real_task_folder);
    assert_eq!(created.worktrees[0].origin, WorktreeOrigin::Created);
    assert_eq!(retried.worktrees[0].origin, WorktreeOrigin::Reused);
    assert_eq!(retried.mounts, created.mounts);
    assert_eq!(checked_out_branch(&worktree)?, plan.branch);
    assert_eq!(fs::read_to_string(worktree.join("README.md"))?, "hello");
    assert!(worktree.join("notes.txt").exists());
    assert_eq!(worktree.parent(), Some(plan.task_folder.as_path()));
    Ok(())
}

#[test]
fn gives_every_job_run_a_fresh_folder_and_branch() -> TestResult<()> {
    let folders = prepare_runner_folders()?;
    let origin = create_origin(&folders, "app")?;
    let clone_locks = CloneLocks::default();
    let title = "Nightly dependency update";
    let first_run = WorktreeLifetime::PerJobRun { run_number: 1 };
    let second_run = WorktreeLifetime::PerJobRun { run_number: 2 };
    let first_plan = plan_task(&folders, &origin, title, first_run)?;
    let second_plan = plan_task(&folders, &origin, title, second_run)?;

    let first = create_worktrees(&first_plan, &clone_locks)?;
    let second = create_worktrees(&second_plan, &clone_locks)?;

    let second_worktree = first_worktree(&second_plan)?;
    assert_ne!(first.mounts.task_folder, second.mounts.task_folder);
    assert_eq!(second.worktrees[0].origin, WorktreeOrigin::Created);
    assert_eq!(checked_out_branch(&second_worktree)?, second_plan.branch);
    assert!(second_plan.branch.ends_with("-run-2"));
    assert!(first_worktree(&first_plan)?.join("README.md").exists());
    Ok(())
}

#[test]
fn removes_worktrees_and_deletes_branches_only_when_asked() -> TestResult<()> {
    let folders = prepare_runner_folders()?;
    let origin = create_origin(&folders, "app")?;
    let clone_locks = CloneLocks::default();
    let lifetime = WorktreeLifetime::PerTask;
    let plan = plan_task(&folders, &origin, "Clean up logs", lifetime)?;
    let cached_clone = first_cached_clone(&plan)?;
    create_worktrees(&plan, &clone_locks)?;
    fs::write(first_worktree(&plan)?.join("scratch.txt"), "uncommitted")?;

    remove_worktrees(&plan, &clone_locks)?;
    let is_branch_kept = branch_exists(&cached_clone, &plan.branch);
    delete_task_branches(&plan, &clone_locks)?;

    assert!(!plan.task_folder.exists());
    assert!(is_branch_kept);
    assert!(!branch_exists(&cached_clone, &plan.branch));
    Ok(())
}

#[test]
fn fetches_new_commits_for_later_tasks() -> TestResult<()> {
    let folders = prepare_runner_folders()?;
    let origin = create_origin(&folders, "app")?;
    let clone_locks = CloneLocks::default();
    let lifetime = WorktreeLifetime::PerTask;
    let first_plan = plan_task(&folders, &origin, "First task", lifetime)?;
    create_worktrees(&first_plan, &clone_locks)?;
    commit_file(&origin, "CHANGELOG.md", "new release")?;
    let second_plan = plan_task(&folders, &origin, "Second task", lifetime)?;

    create_worktrees(&second_plan, &clone_locks)?;

    let second_worktree = first_worktree(&second_plan)?;
    let first_worktree = first_worktree(&first_plan)?;
    assert!(second_worktree.join("CHANGELOG.md").exists());
    assert!(!first_worktree.join("CHANGELOG.md").exists());
    Ok(())
}

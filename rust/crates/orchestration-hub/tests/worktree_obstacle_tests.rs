mod git_support;

use std::fmt::Display;
use std::fs;
use std::os::unix::fs::symlink;
use std::path::PathBuf;

use git_support::{
    RunnerFolders, TestResult, create_origin, numbered_task_id, plan_for,
    prepare_runner_folders,
};
use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreePlan};
use orchestration_hub::worktrees::{WorktreeError, create_worktrees};
use proptest::prelude::*;

const TASK_NUMBER: u128 = 0x5eed;
const REPOSITORY_NAME: &str = "app";
const BLOCKING_FILE_CONTENT: &str = "not a folder";

#[derive(Clone, Copy, Debug)]
enum BlockedSpot {
    TaskFolder,
    RepositoryWorktree,
}

#[derive(Clone, Copy, Debug)]
enum Blocker {
    PlainFile,
    LinkToCacheRoot,
}

fn any_spot() -> impl Strategy<Value = BlockedSpot> {
    prop_oneof![
        Just(BlockedSpot::TaskFolder),
        Just(BlockedSpot::RepositoryWorktree),
    ]
}

fn any_blocker() -> impl Strategy<Value = Blocker> {
    prop_oneof![Just(Blocker::PlainFile), Just(Blocker::LinkToCacheRoot)]
}

fn any_lifetime() -> impl Strategy<Value = WorktreeLifetime> {
    prop_oneof![
        Just(WorktreeLifetime::PerTask),
        (1_u32..100).prop_map(job_run),
    ]
}

fn job_run(run_number: u32) -> WorktreeLifetime {
    WorktreeLifetime::PerJobRun { run_number }
}

fn to_case_error(problem: impl Display) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

fn block_spot(
    folders: &RunnerFolders,
    plan: &WorktreePlan,
    spot: BlockedSpot,
    blocker: Blocker,
) -> TestResult<PathBuf> {
    fs::create_dir_all(&folders.cache_root)?;
    fs::create_dir_all(&folders.worktrees_root)?;
    let blocked_path = match spot {
        BlockedSpot::TaskFolder => plan.task_folder.clone(),
        BlockedSpot::RepositoryWorktree => {
            fs::create_dir_all(&plan.task_folder)?;
            plan.task_folder.join(REPOSITORY_NAME)
        }
    };

    match blocker {
        Blocker::PlainFile => fs::write(&blocked_path, BLOCKING_FILE_CONTENT)?,
        Blocker::LinkToCacheRoot => {
            symlink(&folders.cache_root, &blocked_path)?;
        }
    }
    Ok(blocked_path)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(8))]

    #[test]
    fn test_create_worktrees_property_refuses_a_folder_taken_by_a_file_or_link(
        spot in any_spot(),
        blocker in any_blocker(),
        title in "[a-zA-Z ]{0,20}",
        lifetime in any_lifetime(),
    ) {
        let folders = prepare_runner_folders().map_err(to_case_error)?;
        let origin =
            create_origin(&folders, REPOSITORY_NAME).map_err(to_case_error)?;
        let task_id = numbered_task_id(TASK_NUMBER).map_err(to_case_error)?;
        let plan = plan_for(&folders, task_id, &title, lifetime, &[origin])
            .map_err(to_case_error)?;
        let blocked_path = block_spot(&folders, &plan, spot, blocker)
            .map_err(to_case_error)?;

        let creation = create_worktrees(&plan, &CloneLocks::default());

        let is_refused_for_the_blocked_path = matches!(
            &creation,
            Err(WorktreeError::BlockedFolder(path)) if *path == blocked_path
        );
        prop_assert!(is_refused_for_the_blocked_path, "{creation:?}");
        let cache_entries = fs::read_dir(&folders.cache_root)
            .map_err(to_case_error)?;
        prop_assert_eq!(cache_entries.count(), 0);
        let blocker_metadata = fs::symlink_metadata(&blocked_path)
            .map_err(to_case_error)?;
        prop_assert!(!blocker_metadata.is_dir());
    }
}

use std::fs;

use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::workspace_mounts::GIT_DIRECTORY_NAME;
use orchestration_hub::worktrees::{
    WorktreeError, WorktreeOrigin, create_worktrees,
};
use proptest::prelude::*;

use crate::git_support::commit_file;
use crate::held_folders::to_case_error;
use crate::worktree_folders::{
    GIT_CASES, REPOSITORY_NAMES, create, create_origins, git, plan_task,
    prepare_folders,
};
use crate::worktree_support::{any_hostile_title, any_lifetime};

const FIRST_TASK: u128 = 0x3333_0000_0000_4000_8000_0000_0000_0003;
const SECOND_TASK: u128 = 0x4444_0000_0000_4000_8000_0000_0000_0004;
const CLONE_MARKER: &str = "kept-by-the-test";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_is_git_checkout_property_checkouts_are_reused_without_origin(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        repository_count in 1..=REPOSITORY_NAMES.len(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, repository_count)?;
        let plan =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;
        create(&plan)?;
        for origin in &origins {
            fs::remove_dir_all(origin).map_err(to_case_error)?;
        }

        let again = create(&plan)?;

        for worktree in &again.worktrees {
            prop_assert_eq!(worktree.origin, WorktreeOrigin::Reused);
        }
    }

    #[test]
    fn test_is_git_checkout_property_cached_clones_are_fetched_not_cloned(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let first =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;
        create(&first)?;
        let cached_clone = &first.repositories[0].cached_clone;
        let marker = cached_clone.join(GIT_DIRECTORY_NAME).join(CLONE_MARKER);
        fs::write(&marker, "marker").map_err(to_case_error)?;

        let second =
            plan_task(&folders, SECOND_TASK, &title, lifetime, &origins)?;
        let prepared = create(&second)?;

        prop_assert_eq!(prepared.worktrees[0].origin, WorktreeOrigin::Created);
        prop_assert!(marker.is_file());
    }

    #[test]
    fn test_is_git_checkout_property_a_deleted_worktree_keeps_its_work(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        note in "[a-z]{1,20}",
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;
        create(&plan)?;
        let worktree = &plan.repositories[0].worktree;
        commit_file(worktree, "work.txt", &note).map_err(to_case_error)?;
        let work_commit = git(worktree, &["rev-parse", "HEAD"])?;
        fs::remove_dir_all(worktree).map_err(to_case_error)?;

        let again = create_worktrees(&plan, &CloneLocks::default());

        let cached_clone = &plan.repositories[0].cached_clone;
        let branch_commit = git(cached_clone, &["rev-parse", &plan.branch])?;
        prop_assert_eq!(&branch_commit, &work_commit);
        let is_git_failure =
            matches!(again, Err(WorktreeError::GitFailed { .. }));
        prop_assert!(again.is_ok() || is_git_failure, "{:?}", again);
    }

    #[test]
    fn test_fetch_command_property_later_tasks_see_origin_branches_change(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        (gone_branch, new_branch) in ("gone-[a-z]{1,6}", "new-[a-z]{1,6}"),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let origin = &origins[0];
        git(origin, &["branch", &gone_branch])?;
        let first =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;
        create(&first)?;
        git(origin, &["branch", "-D", &gone_branch])?;
        git(origin, &["branch", &new_branch])?;

        let second =
            plan_task(&folders, SECOND_TASK, &title, lifetime, &origins)?;
        create(&second)?;

        let cached_clone = &second.repositories[0].cached_clone;
        let remote_branches = git(
            cached_clone,
            &["for-each-ref", "--format=%(refname:short)", "refs/remotes"],
        )?;
        let listed: Vec<&str> = remote_branches.lines().collect();
        let gone = format!("origin/{gone_branch}");
        let new = format!("origin/{new_branch}");
        prop_assert!(!listed.contains(&gone.as_str()), "{:?}", listed);
        prop_assert!(listed.contains(&new.as_str()), "{:?}", listed);
    }
}

use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreePlan};
use orchestration_hub::worktrees::{
    WorktreeError, delete_task_branches, remove_worktrees,
};
use proptest::prelude::*;

use crate::git_support::commit_file;
use crate::held_folders::to_case_error;
use crate::worktree_folders::{
    CaseResult, GIT_CASES, REPOSITORY_NAMES, branch_exists, create,
    create_origins, git, plan_task, prepare_folders,
};
use crate::worktree_support::{any_hostile_title, any_lifetime};

const FIRST_TASK: u128 = 0x6666_0000_0000_4000_8000_0000_0000_0006;
const SECOND_TASK: u128 = 0x7777_0000_0000_4000_8000_0000_0000_0007;
const WORKTREE_LINE_PREFIX: &str = "worktree ";

fn remove(plan: &WorktreePlan) -> CaseResult<()> {
    remove_worktrees(plan, &CloneLocks::default()).map_err(to_case_error)
}

fn delete(plan: &WorktreePlan) -> Result<(), WorktreeError> {
    delete_task_branches(plan, &CloneLocks::default())
}

fn count_worktrees(plan: &WorktreePlan) -> CaseResult<usize> {
    let cached_clone = &plan.repositories[0].cached_clone;
    let listing = git(cached_clone, &["worktree", "list", "--porcelain"])?;
    let count = listing
        .lines()
        .filter(|line| line.starts_with(WORKTREE_LINE_PREFIX))
        .count();
    Ok(count)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_remove_worktrees_property_leaves_no_folder_but_keeps_branch(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        repository_count in 1..=REPOSITORY_NAMES.len(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, repository_count)?;
        let plan =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;
        create(&plan)?;

        remove(&plan)?;

        prop_assert!(!plan.task_folder.exists());
        for repository in &plan.repositories {
            prop_assert!(branch_exists(
                &repository.cached_clone,
                &plan.branch
            )?);
        }
        prop_assert_eq!(count_worktrees(&plan)?, 1);
    }

    #[test]
    fn test_remove_worktrees_property_removing_again_is_harmless(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        is_ever_created in any::<bool>(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;
        if is_ever_created {
            create(&plan)?;
        }

        remove(&plan)?;
        remove(&plan)?;

        prop_assert!(!plan.task_folder.exists());
    }

    #[test]
    fn test_remove_worktrees_property_other_tasks_keep_their_worktrees(
        title in any_hostile_title(),
        note in "[a-z]{1,20}",
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let lifetime = WorktreeLifetime::PerTask;
        let first =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;
        let second =
            plan_task(&folders, SECOND_TASK, &title, lifetime, &origins)?;
        create(&first)?;
        create(&second)?;
        let kept_worktree = &second.repositories[0].worktree;
        std::fs::write(kept_worktree.join("notes.txt"), &note)
            .map_err(to_case_error)?;

        remove(&first)?;

        let kept_note =
            std::fs::read_to_string(kept_worktree.join("notes.txt"))
                .map_err(to_case_error)?;
        prop_assert_eq!(kept_note, note);
        let branch = git(kept_worktree, &["symbolic-ref", "--short", "HEAD"])?;
        prop_assert_eq!(branch, second.branch.clone());
        prop_assert_eq!(count_worktrees(&second)?, 2);
    }

    #[test]
    fn test_delete_task_branches_property_deletes_only_the_task_branch(
        title in any_hostile_title(),
        repository_count in 1..=REPOSITORY_NAMES.len(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, repository_count)?;
        let lifetime = WorktreeLifetime::PerTask;
        let first =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;
        let second =
            plan_task(&folders, SECOND_TASK, &title, lifetime, &origins)?;
        create(&first)?;
        create(&second)?;
        remove(&first)?;

        delete(&first).map_err(to_case_error)?;

        for repository in &first.repositories {
            let clone = &repository.cached_clone;
            prop_assert!(!branch_exists(clone, &first.branch)?);
            prop_assert!(branch_exists(clone, &second.branch)?);
        }
    }

    #[test]
    fn test_delete_task_branches_property_unmerged_work_is_deleted_too(
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
        remove(&plan)?;

        delete(&plan).map_err(to_case_error)?;

        prop_assert!(!branch_exists(
            &plan.repositories[0].cached_clone,
            &plan.branch
        )?);
    }

    #[test]
    fn test_delete_task_branches_property_a_checked_out_branch_is_kept(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;
        create(&plan)?;

        let deletion = delete(&plan);

        let is_git_failure =
            matches!(deletion, Err(WorktreeError::GitFailed { .. }));
        prop_assert!(is_git_failure, "{:?}", deletion);
        let clone = &plan.repositories[0].cached_clone;
        prop_assert!(branch_exists(clone, &plan.branch)?);
        prop_assert!(
            plan.repositories[0].worktree.join("README.md").is_file()
        );
    }
}

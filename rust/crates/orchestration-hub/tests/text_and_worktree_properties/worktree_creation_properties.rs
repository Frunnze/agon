use std::fs;

use orchestration_hub::workspace_mounts::GIT_DIRECTORY_NAME;
use orchestration_hub::worktree_plan::WorktreeLifetime;
use orchestration_hub::worktrees::WorktreeOrigin;
use proptest::prelude::*;

use crate::git_support::commit_file;
use crate::held_folders::to_case_error;
use crate::worktree_folders::{
    GIT_CASES, REPOSITORY_NAMES, create, create_origins, git, plan_task,
    prepare_folders,
};
use crate::worktree_support::{any_hostile_title, any_lifetime};

const FIRST_TASK: u128 = 0x1111_0000_0000_4000_8000_0000_0000_0001;
const SECOND_TASK: u128 = 0x2222_0000_0000_4000_8000_0000_0000_0002;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_create_worktrees_property_second_creation_reuses_everything(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        repository_count in 1..=REPOSITORY_NAMES.len(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, repository_count)?;
        let plan =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;

        let first = create(&plan)?;
        let replanned =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;
        let second = create(&replanned)?;

        prop_assert_eq!(&replanned, &plan);
        let are_all_created = first
            .worktrees
            .iter()
            .all(|worktree| worktree.origin == WorktreeOrigin::Created);
        let are_all_reused = second
            .worktrees
            .iter()
            .all(|worktree| worktree.origin == WorktreeOrigin::Reused);
        prop_assert!(are_all_created);
        prop_assert!(are_all_reused);
        prop_assert_eq!(first.mounts, second.mounts);
    }

    #[test]
    fn test_create_worktrees_property_worktrees_start_on_the_task_branch(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        repository_count in 1..=REPOSITORY_NAMES.len(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, repository_count)?;
        let plan =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;

        create(&plan)?;

        let expected_head = format!("refs/heads/{}", plan.branch);
        for (repository, origin) in plan.repositories.iter().zip(&origins) {
            let head = git(&repository.worktree, &["symbolic-ref", "HEAD"])?;
            let commit = git(&repository.worktree, &["rev-parse", "HEAD"])?;
            let origin_commit = git(origin, &["rev-parse", "main"])?;
            prop_assert_eq!(&head, &expected_head);
            prop_assert_eq!(commit, origin_commit);
        }
    }

    #[test]
    fn test_create_worktrees_property_mounts_hold_the_real_folders(
        title in any_hostile_title(),
        repository_count in 1..=REPOSITORY_NAMES.len(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, repository_count)?;
        let lifetime = WorktreeLifetime::PerTask;
        let plan =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;

        let prepared = create(&plan)?;

        let real_task_folder =
            plan.task_folder.canonicalize().map_err(to_case_error)?;
        prop_assert_eq!(&prepared.mounts.task_folder, &real_task_folder);
        prop_assert!(prepared.mounts.placeholder_mounts.is_empty());
        let mut expected_git_directories = Vec::new();
        for repository in &plan.repositories {
            let git_directory =
                repository.cached_clone.join(GIT_DIRECTORY_NAME);
            expected_git_directories
                .push(git_directory.canonicalize().map_err(to_case_error)?);
        }
        prop_assert_eq!(
            &prepared.mounts.git_directories,
            &expected_git_directories
        );
        let prepared_paths: Vec<_> = prepared
            .worktrees
            .iter()
            .map(|worktree| worktree.path.clone())
            .collect();
        let planned_paths: Vec<_> = plan
            .repositories
            .iter()
            .map(|planned| planned.worktree.clone())
            .collect();
        prop_assert_eq!(prepared_paths, planned_paths);
    }

    #[test]
    fn test_prepare_repository_worktree_property_new_commits_reach_new_tasks(
        title in any_hostile_title(),
        note in "[a-z]{1,20}",
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let lifetime = WorktreeLifetime::PerTask;
        let first =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;
        create(&first)?;
        let old_commit = git(&origins[0], &["rev-parse", "main"])?;
        commit_file(&origins[0], "notes.txt", &note).map_err(to_case_error)?;
        let new_commit = git(&origins[0], &["rev-parse", "main"])?;

        let second =
            plan_task(&folders, SECOND_TASK, &title, lifetime, &origins)?;
        create(&second)?;

        let first_head =
            git(&first.repositories[0].worktree, &["rev-parse", "HEAD"])?;
        let second_head =
            git(&second.repositories[0].worktree, &["rev-parse", "HEAD"])?;
        prop_assert_eq!(first_head, old_commit);
        prop_assert_eq!(second_head, new_commit);
    }

    #[test]
    fn test_prepare_repository_worktree_property_empty_leftover_is_filled(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, FIRST_TASK, &title, lifetime, &origins)?;
        let worktree = &plan.repositories[0].worktree;
        fs::create_dir_all(worktree).map_err(to_case_error)?;

        let prepared = create(&plan)?;

        prop_assert_eq!(prepared.worktrees[0].origin, WorktreeOrigin::Created);
        prop_assert!(worktree.join("README.md").is_file());
    }

    #[test]
    fn test_prepare_repository_worktree_property_tasks_share_one_clone(
        title in any_hostile_title(),
        task_count in 2_u128..5,
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let lifetime = WorktreeLifetime::PerTask;
        let mut plans = Vec::new();
        for task_number in 1..=task_count {
            let plan =
                plan_task(&folders, task_number, &title, lifetime, &origins)?;
            create(&plan)?;
            plans.push(plan);
        }

        let cached_clone = plans[0].repositories[0].cached_clone.clone();
        let listing =
            git(&cached_clone, &["worktree", "list", "--porcelain"])?;
        for plan in &plans {
            prop_assert_eq!(&plan.repositories[0].cached_clone, &cached_clone);
            let worktree = plan.repositories[0]
                .worktree
                .canonicalize()
                .map_err(to_case_error)?;
            let line = format!("worktree {}", worktree.display());
            prop_assert!(
                listing.lines().any(|listed| listed == line),
                "{}",
                listing
            );
        }
    }
}

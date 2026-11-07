use std::fs;

use orchestration_hub::workspace_mounts::GIT_DIRECTORY_NAME;
use orchestration_hub::worktrees::WorktreeOrigin;
use proptest::prelude::*;

use crate::held_folders::to_case_error;
use crate::recovery_support::{
    RECOVERED_TASK, WORK_FILE_NAME, branch_commit, checked_out_branch,
    commit_work, delete_by_hand, head_commit, read_text, try_create,
};
use crate::worktree_folders::{
    GIT_CASES, REPOSITORY_NAMES, create, create_origins, git, plan_task,
    prepare_folders,
};
use crate::worktree_support::{any_hostile_title, any_lifetime};

const PRECIOUS_FILE_NAME: &str = "precious.txt";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_create_worktrees_property_deleted_worktree_returns_on_its_branch(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        note in "[a-z]{1,20}",
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, RECOVERED_TASK, &title, lifetime, &origins)?;
        create(&plan)?;
        let worktree = &plan.repositories[0].worktree;
        let work_commit = commit_work(worktree, WORK_FILE_NAME, &note)?;
        delete_by_hand(worktree)?;

        let again = try_create(&plan);

        prop_assert!(again.is_ok(), "{:?}", again);
        prop_assert_eq!(head_commit(worktree)?, work_commit);
        prop_assert_eq!(checked_out_branch(worktree)?, plan.branch.clone());
        prop_assert_eq!(read_text(&worktree.join(WORK_FILE_NAME))?, note);
    }

    #[test]
    fn test_create_worktrees_property_deleted_task_folder_returns_whole(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        repository_count in 1..=REPOSITORY_NAMES.len(),
        notes in proptest::collection::vec("[a-z]{1,12}", 3),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, repository_count)?;
        let plan =
            plan_task(&folders, RECOVERED_TASK, &title, lifetime, &origins)?;
        create(&plan)?;
        let mut work_commits = Vec::new();
        for (repository, note) in plan.repositories.iter().zip(&notes) {
            let worktree = &repository.worktree;
            work_commits.push(commit_work(worktree, WORK_FILE_NAME, note)?);
        }
        delete_by_hand(&plan.task_folder)?;

        let again = try_create(&plan);

        prop_assert!(again.is_ok(), "{:?}", again);
        let recovered = plan.repositories.iter().zip(&work_commits);
        for ((repository, work_commit), note) in recovered.zip(&notes) {
            let worktree = &repository.worktree;
            prop_assert_eq!(&head_commit(worktree)?, work_commit);
            prop_assert_eq!(&read_text(&worktree.join(WORK_FILE_NAME))?, note);
        }
    }

    #[test]
    fn test_create_worktrees_property_returned_worktree_is_reused_next(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        note in "[a-z]{1,20}",
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, RECOVERED_TASK, &title, lifetime, &origins)?;
        create(&plan)?;
        let worktree = &plan.repositories[0].worktree;
        let work_commit = commit_work(worktree, WORK_FILE_NAME, &note)?;
        delete_by_hand(worktree)?;
        try_create(&plan).map_err(to_case_error)?;

        let third = create(&plan)?;

        prop_assert_eq!(third.worktrees[0].origin, WorktreeOrigin::Reused);
        let real_task_folder =
            plan.task_folder.canonicalize().map_err(to_case_error)?;
        prop_assert_eq!(&third.mounts.task_folder, &real_task_folder);
        prop_assert_eq!(head_commit(worktree)?, work_commit);
    }

    #[test]
    fn test_prepare_repository_worktree_property_return_is_reported_created(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        repository_count in 2..=REPOSITORY_NAMES.len(),
        deleted_index in 0..REPOSITORY_NAMES.len(),
    ) {
        let deleted_index = deleted_index % repository_count;
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, repository_count)?;
        let plan =
            plan_task(&folders, RECOVERED_TASK, &title, lifetime, &origins)?;
        create(&plan)?;
        let deleted = &plan.repositories[deleted_index].worktree;
        commit_work(deleted, WORK_FILE_NAME, "lost folder")?;
        delete_by_hand(deleted)?;

        let again = try_create(&plan).map_err(to_case_error)?;

        for (index, worktree) in again.worktrees.iter().enumerate() {
            let expected_origin = if index == deleted_index {
                WorktreeOrigin::Created
            } else {
                WorktreeOrigin::Reused
            };
            prop_assert_eq!(worktree.origin, expected_origin);
        }
    }

    #[test]
    fn test_prepare_repository_worktree_property_repeated_loss_keeps_commits(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        lost_task_folders in prop::collection::vec(any::<bool>(), 1..4),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, RECOVERED_TASK, &title, lifetime, &origins)?;
        create(&plan)?;
        let worktree = &plan.repositories[0].worktree;
        let mut work_commits = Vec::new();
        let cycles = lost_task_folders.iter().enumerate();
        for (cycle, is_task_folder_lost) in cycles {
            let file_name = format!("work-{cycle}.txt");
            work_commits.push(commit_work(worktree, &file_name, "cycle")?);
            if *is_task_folder_lost {
                delete_by_hand(&plan.task_folder)?;
            } else {
                delete_by_hand(worktree)?;
            }
            try_create(&plan).map_err(to_case_error)?;
        }

        let history = git(worktree, &["rev-list", "HEAD"])?;
        let listed: Vec<&str> = history.lines().collect();
        for (cycle, work_commit) in work_commits.iter().enumerate() {
            prop_assert!(listed.contains(&work_commit.as_str()));
            let file_name = format!("work-{cycle}.txt");
            prop_assert!(worktree.join(file_name).is_file());
        }
        let last_commit = work_commits.last().cloned().unwrap_or_default();
        prop_assert_eq!(branch_commit(&plan, 0)?, last_commit);
    }

    #[test]
    fn test_prepare_repository_worktree_property_filled_folder_is_left_alone(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        precious_text in "[a-z ]{1,30}",
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, RECOVERED_TASK, &title, lifetime, &origins)?;
        create(&plan)?;
        let worktree = &plan.repositories[0].worktree;
        let work_commit = commit_work(worktree, WORK_FILE_NAME, "work")?;
        let checkout_link = worktree.join(GIT_DIRECTORY_NAME);
        fs::remove_file(&checkout_link).map_err(to_case_error)?;
        let precious_file = worktree.join(PRECIOUS_FILE_NAME);
        fs::write(&precious_file, &precious_text).map_err(to_case_error)?;

        let again = try_create(&plan);

        prop_assert!(again.is_err(), "{:?}", again);
        prop_assert_eq!(read_text(&precious_file)?, precious_text);
        prop_assert!(!checkout_link.exists());
        prop_assert_eq!(branch_commit(&plan, 0)?, work_commit);
    }
}

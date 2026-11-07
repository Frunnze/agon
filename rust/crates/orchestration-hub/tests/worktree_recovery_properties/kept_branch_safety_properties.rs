use std::fs;
use std::path::Path;

use orchestration_hub::workspace_mounts::GIT_DIRECTORY_NAME;
use proptest::prelude::*;

use crate::git_support::commit_file;
use crate::held_folders::to_case_error;
use crate::recovery_support::{
    NEIGHBOUR_TASK, RECOVERED_TASK, WORK_FILE_NAME, branch_commit,
    checked_out_branch, commit_work, delete_by_hand, head_commit, try_create,
};
use crate::worktree_folders::{
    CaseResult, GIT_CASES, create, create_origins, git, plan_task,
    prepare_folders,
};
use crate::worktree_support::{any_hostile_title, any_lifetime};

const WORKTREE_LINE_PREFIX: &str = "worktree ";
const PRUNABLE_LINE_PREFIX: &str = "prunable";
const MOVED_FOLDER_NAME: &str = "moved-away";
const ORIGIN_NOTE_FILE_NAME: &str = "origin-news.txt";

fn list_worktree_records(cached_clone: &Path) -> CaseResult<Vec<String>> {
    let listing = git(cached_clone, &["worktree", "list", "--porcelain"])?;
    let mut records = Vec::new();
    for line in listing.lines() {
        records.push(line.to_owned());
    }
    Ok(records)
}

fn worktree_record_line(worktree: &Path) -> CaseResult<String> {
    let real_worktree = worktree.canonicalize().map_err(to_case_error)?;
    Ok(format!("{WORKTREE_LINE_PREFIX}{}", real_worktree.display()))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_add_task_worktree_property_kept_branch_is_never_moved(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        (note, origin_news) in ("[a-z]{1,12}", "[a-z]{1,12}"),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, RECOVERED_TASK, &title, lifetime, &origins)?;
        create(&plan)?;
        let worktree = &plan.repositories[0].worktree;
        let work_commit = commit_work(worktree, WORK_FILE_NAME, &note)?;
        let origin = &origins[0];
        commit_file(origin, ORIGIN_NOTE_FILE_NAME, &origin_news)
            .map_err(to_case_error)?;
        delete_by_hand(worktree)?;

        try_create(&plan).map_err(to_case_error)?;

        prop_assert_eq!(branch_commit(&plan, 0)?, work_commit.clone());
        prop_assert_eq!(head_commit(worktree)?, work_commit);
        prop_assert!(!worktree.join(ORIGIN_NOTE_FILE_NAME).exists());
    }

    #[test]
    fn test_add_task_worktree_property_stale_record_is_pruned(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        loss_count in 1_usize..4,
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, RECOVERED_TASK, &title, lifetime, &origins)?;
        create(&plan)?;
        let worktree = &plan.repositories[0].worktree;
        for _ in 0..loss_count {
            delete_by_hand(worktree)?;
            try_create(&plan).map_err(to_case_error)?;
        }

        let cached_clone = &plan.repositories[0].cached_clone;
        let records = list_worktree_records(cached_clone)?;

        let record_line = worktree_record_line(worktree)?;
        let matching_count =
            records.iter().filter(|line| **line == record_line).count();
        prop_assert_eq!(matching_count, 1, "{:?}", records);
        let has_prunable = records
            .iter()
            .any(|line| line.starts_with(PRUNABLE_LINE_PREFIX));
        prop_assert!(!has_prunable, "{:?}", records);
    }

    #[test]
    fn test_add_task_worktree_property_branch_in_use_elsewhere_is_kept(
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
        let moved_parent = folders.temporary.path().join(MOVED_FOLDER_NAME);
        fs::create_dir_all(&moved_parent).map_err(to_case_error)?;
        let moved = moved_parent.join(RECOVERED_TASK.to_string());
        let cached_clone = &plan.repositories[0].cached_clone;
        let worktree_text = worktree.display().to_string();
        let moved_text = moved.display().to_string();
        git(cached_clone, &["worktree", "move", &worktree_text, &moved_text])?;

        let again = try_create(&plan);

        prop_assert!(again.is_err(), "{:?}", again);
        prop_assert!(moved.join(GIT_DIRECTORY_NAME).exists());
        prop_assert_eq!(head_commit(&moved)?, work_commit.clone());
        prop_assert_eq!(checked_out_branch(&moved)?, plan.branch.clone());
        prop_assert_eq!(branch_commit(&plan, 0)?, work_commit);
    }

    #[test]
    fn test_add_task_worktree_property_new_task_still_starts_at_origin(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        note in "[a-z]{1,20}",
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let lost =
            plan_task(&folders, RECOVERED_TASK, &title, lifetime, &origins)?;
        create(&lost)?;
        let lost_worktree = &lost.repositories[0].worktree;
        let work_commit = commit_work(lost_worktree, WORK_FILE_NAME, &note)?;
        delete_by_hand(lost_worktree)?;
        let origin_commit = git(&origins[0], &["rev-parse", "main"])?;

        let fresh =
            plan_task(&folders, NEIGHBOUR_TASK, &title, lifetime, &origins)?;
        let prepared = try_create(&fresh);

        prop_assert!(prepared.is_ok(), "{:?}", prepared);
        let fresh_worktree = &fresh.repositories[0].worktree;
        prop_assert_eq!(head_commit(fresh_worktree)?, origin_commit);
        prop_assert_eq!(
            checked_out_branch(fresh_worktree)?,
            fresh.branch.clone()
        );
        prop_assert_eq!(branch_commit(&lost, 0)?, work_commit);
    }
}

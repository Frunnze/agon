use std::collections::BTreeSet;
use std::fs;

use orchestration_hub::cached_clones::list_cached_repositories;
use orchestration_hub::held_work::list_held_work;
use orchestration_hub::leftover_removal::{
    remove_forgotten_tasks, remove_unused_clones,
};
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreePlan};
use orchestration_hub::worktree_roots::WorktreeRoots;
use proptest::prelude::*;

use crate::git_support::{RunnerFolders, numbered_task_id};
use crate::held_folders::{
    TASK_BRANCH_PREFIX, any_address, any_slug, any_task_id,
    create_cached_clone, create_held_folders, task_folder_name, to_case_error,
};
use crate::worktree_folders::{
    CaseResult, GIT_CASES, branch_exists, create, create_origins, git,
    plan_task, prepare_folders,
};
use crate::worktree_support::any_hostile_title;

const FIRST_TASK: u128 = 0x9999_0000_0000_4000_8000_0000_0000_0009;
const SECOND_TASK: u128 = 0xaaaa_0000_0000_4000_8000_0000_0000_000a;
const OUTSIDE_FOLDER_NAME: &str = "outside-worktree";

fn roots_of(folders: &RunnerFolders) -> WorktreeRoots {
    WorktreeRoots {
        cache_root: folders.cache_root.clone(),
        worktrees_root: folders.worktrees_root.clone(),
    }
}

fn address_of(folders: &RunnerFolders) -> CaseResult<String> {
    let addresses = list_cached_repositories(&folders.cache_root)
        .map_err(to_case_error)?;
    addresses
        .into_iter()
        .next()
        .ok_or_else(|| to_case_error("no cached repository"))
}

fn two_tasks(
    title: &str,
) -> CaseResult<(RunnerFolders, WorktreePlan, WorktreePlan)> {
    let folders = prepare_folders()?;
    let origins = create_origins(&folders, 1)?;
    let lifetime = WorktreeLifetime::PerTask;
    let first = plan_task(&folders, FIRST_TASK, title, lifetime, &origins)?;
    let second = plan_task(&folders, SECOND_TASK, title, lifetime, &origins)?;
    create(&first)?;
    create(&second)?;
    Ok((folders, first, second))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_list_task_branches_command_property_lists_only_local_task_branches(
        address in any_address(),
        task_id in any_task_id(),
        slug in any_slug(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let name = task_folder_name(&slug, task_id);
        let task_branch = format!("{TASK_BRANCH_PREFIX}{name}");
        let lookalikes = vec![
            format!("tasks/{name}"),
            format!("task-{name}"),
            format!("old/{TASK_BRANCH_PREFIX}{name}"),
        ];
        let mut branches = lookalikes;
        branches.push(task_branch.clone());
        let clone = create_cached_clone(
            &folders.roots.cache_root,
            &address,
            &branches,
        )
        .map_err(to_case_error)?;
        let remote_reference =
            format!("refs/remotes/origin/{TASK_BRANCH_PREFIX}{slug}-other");
        git(&clone, &["update-ref", &remote_reference, "HEAD"])?;

        let held_work =
            list_held_work(&folders.roots).map_err(to_case_error)?;

        let listed: Vec<&str> = held_work
            .task_branches
            .iter()
            .map(|listed_branch| listed_branch.branch.as_str())
            .collect();
        prop_assert_eq!(listed, vec![task_branch.as_str()]);
        prop_assert_eq!(held_work.task_branches[0].task_id, task_id);
    }

    #[test]
    fn test_list_task_branches_command_property_every_clone_is_asked(
        addresses in proptest::collection::btree_set(any_address(), 1..4),
        task_id in any_task_id(),
        slug in any_slug(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let task_branch = format!(
            "{TASK_BRANCH_PREFIX}{}",
            task_folder_name(&slug, task_id)
        );
        let mut clones = BTreeSet::new();
        for address in &addresses {
            let clone = create_cached_clone(
                &folders.roots.cache_root,
                address,
                std::slice::from_ref(&task_branch),
            )
            .map_err(to_case_error)?;
            clones.insert(clone);
        }

        let held_work =
            list_held_work(&folders.roots).map_err(to_case_error)?;

        let listed_clones: BTreeSet<_> = held_work
            .task_branches
            .iter()
            .map(|listed_branch| listed_branch.cached_clone.clone())
            .collect();
        prop_assert_eq!(listed_clones, clones);
        prop_assert_eq!(held_work.task_branches.len(), addresses.len());
    }

    #[test]
    fn test_list_task_branches_command_property_created_tasks_are_held(
        title in any_hostile_title(),
    ) {
        let (folders, first, second) = two_tasks(&title)?;

        let held_work =
            list_held_work(&roots_of(&folders)).map_err(to_case_error)?;

        let listed: BTreeSet<String> = held_work
            .task_branches
            .iter()
            .map(|listed_branch| listed_branch.branch.clone())
            .collect();
        let expected =
            BTreeSet::from([first.branch.clone(), second.branch.clone()]);
        prop_assert_eq!(listed, expected);
        let first_id = numbered_task_id(FIRST_TASK).map_err(to_case_error)?;
        prop_assert!(held_work.list_task_ids().contains(&first_id));
    }

    #[test]
    fn test_list_worktrees_command_property_unused_clone_takes_its_worktrees(
        title in any_hostile_title(),
    ) {
        let (folders, first, second) = two_tasks(&title)?;
        let address = address_of(&folders)?;

        remove_unused_clones(&roots_of(&folders), &[address])
            .map_err(to_case_error)?;

        prop_assert!(!first.repositories[0].cached_clone.exists());
        prop_assert!(!first.repositories[0].worktree.exists());
        prop_assert!(!second.repositories[0].worktree.exists());
    }

    #[test]
    fn test_list_worktrees_command_property_outside_worktrees_are_kept(
        title in any_hostile_title(),
    ) {
        let (folders, first, _second) = two_tasks(&title)?;
        let clone = &first.repositories[0].cached_clone;
        let outside = folders.temporary.path().join(OUTSIDE_FOLDER_NAME);
        let outside_path = outside.display().to_string();
        git(
            clone,
            &["worktree", "add", "--detach", &outside_path, "HEAD"],
        )?;
        let address = address_of(&folders)?;

        remove_unused_clones(&roots_of(&folders), &[address])
            .map_err(to_case_error)?;

        prop_assert!(outside.join("README.md").is_file());
        prop_assert!(!clone.exists());
    }

    #[test]
    fn test_list_worktrees_command_property_used_clones_are_untouched(
        title in any_hostile_title(),
        other_address in any_address(),
    ) {
        let (folders, first, second) = two_tasks(&title)?;

        remove_unused_clones(&roots_of(&folders), &[other_address])
            .map_err(to_case_error)?;

        prop_assert!(first.repositories[0].cached_clone.exists());
        prop_assert!(
            first.repositories[0].worktree.join("README.md").is_file()
        );
        prop_assert!(
            second.repositories[0].worktree.join("README.md").is_file()
        );
    }

    #[test]
    fn test_prune_worktrees_command_property_forgotten_task_leaves_nothing(
        title in any_hostile_title(),
    ) {
        let (folders, first, _second) = two_tasks(&title)?;
        let held_work =
            list_held_work(&roots_of(&folders)).map_err(to_case_error)?;
        let first_id = numbered_task_id(FIRST_TASK).map_err(to_case_error)?;

        remove_forgotten_tasks(&held_work, &BTreeSet::from([first_id]))
            .map_err(to_case_error)?;

        let clone = &first.repositories[0].cached_clone;
        prop_assert!(!first.task_folder.exists());
        prop_assert!(!branch_exists(clone, &first.branch)?);
        let listing = git(clone, &["worktree", "list", "--porcelain"])?;
        let worktree_lines = listing
            .lines()
            .filter(|line| line.starts_with("worktree "))
            .count();
        prop_assert_eq!(worktree_lines, 2);
    }

    #[test]
    fn test_prune_worktrees_command_property_kept_tasks_stay_whole(
        title in any_hostile_title(),
    ) {
        let (folders, first, second) = two_tasks(&title)?;
        let held_work =
            list_held_work(&roots_of(&folders)).map_err(to_case_error)?;
        let first_id = numbered_task_id(FIRST_TASK).map_err(to_case_error)?;

        remove_forgotten_tasks(&held_work, &BTreeSet::from([first_id]))
            .map_err(to_case_error)?;

        let clone = &second.repositories[0].cached_clone;
        prop_assert!(branch_exists(clone, &second.branch)?);
        let branch = git(
            &second.repositories[0].worktree,
            &["symbolic-ref", "--short", "HEAD"],
        )?;
        prop_assert_eq!(branch, second.branch.clone());
        prop_assert!(first.repositories[0].cached_clone.exists());
    }

    #[test]
    fn test_prune_worktrees_command_property_a_lost_folder_still_frees_branch(
        title in any_hostile_title(),
    ) {
        let (folders, first, _second) = two_tasks(&title)?;
        fs::remove_dir_all(&first.task_folder).map_err(to_case_error)?;
        let held_work =
            list_held_work(&roots_of(&folders)).map_err(to_case_error)?;
        let first_id = numbered_task_id(FIRST_TASK).map_err(to_case_error)?;

        remove_forgotten_tasks(&held_work, &BTreeSet::from([first_id]))
            .map_err(to_case_error)?;

        prop_assert!(!branch_exists(
            &first.repositories[0].cached_clone,
            &first.branch
        )?);
    }
}

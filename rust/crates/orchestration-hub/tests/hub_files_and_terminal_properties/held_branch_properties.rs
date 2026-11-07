use std::collections::BTreeSet;
use std::fs;
use std::os::unix::fs::symlink;
use std::path::PathBuf;
use std::slice::from_ref;

use orchestration_core::identifiers::TaskId;
use orchestration_hub::cached_clones::cached_clone_folder;
use orchestration_hub::held_work::{TaskBranch, list_held_work};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::held_folders::{
    TASK_BRANCH_PREFIX, any_address, any_slug, any_task_id,
    create_cached_clone, create_held_folders, task_folder_name, to_case_error,
};

const GIT_CASES: u32 = 6;
const LARGEST_BRANCH_COUNT: usize = 3;
const OTHER_BRANCHES: [&str; 3] = ["feature/login", "task/without-id", "fix"];

type BranchKey = (PathBuf, String, TaskId);

fn task_branch_name(slug: &str, task_id: TaskId) -> String {
    format!("{TASK_BRANCH_PREFIX}{}", task_folder_name(slug, task_id))
}

fn branch_keys(task_branches: Vec<TaskBranch>) -> BTreeSet<BranchKey> {
    let mut keys = BTreeSet::new();
    for task_branch in task_branches {
        keys.insert((
            task_branch.cached_clone,
            task_branch.branch,
            task_branch.task_id,
        ));
    }
    keys
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_list_task_branches_property_only_task_branches_count(
        address in any_address(),
        tasks in vec((any_slug(), any_task_id()), 0..LARGEST_BRANCH_COUNT),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let mut branches: Vec<String> =
            OTHER_BRANCHES.iter().map(|branch| (*branch).to_owned()).collect();
        let mut expected = BTreeSet::new();
        let clone = cached_clone_folder(&folders.roots.cache_root, &address);
        for (slug, task_id) in &tasks {
            let branch = task_branch_name(slug, *task_id);
            expected.insert((clone.clone(), branch.clone(), *task_id));
            branches.push(branch);
        }
        create_cached_clone(&folders.roots.cache_root, &address, &branches)
            .map_err(to_case_error)?;

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        prop_assert_eq!(branch_keys(held_work.task_branches), expected);
    }

    #[test]
    fn test_list_task_branches_property_branches_stay_with_their_clone(
        addresses in vec(any_address(), 1..LARGEST_BRANCH_COUNT),
        task_ids in vec(any_task_id(), LARGEST_BRANCH_COUNT),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let unique_addresses: BTreeSet<String> =
            addresses.into_iter().collect();
        let mut expected = BTreeSet::new();
        for (address, task_id) in unique_addresses.iter().zip(&task_ids) {
            let branch = task_branch_name("work", *task_id);
            let cache_root = &folders.roots.cache_root;
            let clone =
                create_cached_clone(cache_root, address, from_ref(&branch))
                    .map_err(to_case_error)?;
            expected.insert((clone, branch, *task_id));
        }

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        prop_assert_eq!(branch_keys(held_work.task_branches), expected);
    }

    #[test]
    fn test_list_task_branches_property_run_branches_name_their_task(
        address in any_address(),
        slug in any_slug(),
        task_id in any_task_id(),
        run_number in 1_u32..100,
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let base_branch = task_branch_name(&slug, task_id);
        let branch = format!("{base_branch}-run-{run_number}");
        let cache_root = &folders.roots.cache_root;
        create_cached_clone(cache_root, &address, from_ref(&branch))
            .map_err(to_case_error)?;

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        let branches: Vec<(String, TaskId)> = held_work
            .task_branches
            .into_iter()
            .map(|task_branch| (task_branch.branch, task_branch.task_id))
            .collect();
        prop_assert_eq!(branches, vec![(branch, task_id)]);
    }

    #[test]
    fn test_list_real_clones_property_linked_clones_are_skipped(
        address in any_address(),
        linked_address in any_address(),
        task_id in any_task_id(),
    ) {
        prop_assume!(address != linked_address);
        let folders = create_held_folders().map_err(to_case_error)?;
        let branch = task_branch_name("work", task_id);
        let outside_root = folders.temporary.path().join("outside");
        let outside_clone =
            create_cached_clone(&outside_root, &address, &[branch])
                .map_err(to_case_error)?;
        fs::create_dir_all(&folders.roots.cache_root).map_err(to_case_error)?;
        let link =
            cached_clone_folder(&folders.roots.cache_root, &linked_address);
        symlink(&outside_clone, &link).map_err(to_case_error)?;

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        prop_assert_eq!(held_work.task_branches, Vec::new());
    }

    #[test]
    fn test_list_real_clones_property_folders_without_git_are_skipped(
        address in any_address(),
        task_id in any_task_id(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let branch = task_branch_name("work", task_id);
        let clone =
            create_cached_clone(&folders.roots.cache_root, &address, &[branch])
                .map_err(to_case_error)?;
        fs::remove_dir_all(clone.join(".git")).map_err(to_case_error)?;

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        prop_assert_eq!(held_work.task_branches, Vec::new());
    }

    #[test]
    fn test_list_real_clones_property_odd_folder_names_are_skipped(
        folder_name in "[A-Z][A-Z0-9]{0,8}",
        task_id in any_task_id(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let cache_root = &folders.roots.cache_root;
        let branch = task_branch_name("work", task_id);
        let clone = create_cached_clone(cache_root, "a.test/b/c", &[branch])
            .map_err(to_case_error)?;
        let renamed = cache_root.join(folder_name);
        fs::rename(&clone, &renamed).map_err(to_case_error)?;

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        prop_assert_eq!(held_work.task_branches, Vec::new());
    }
}

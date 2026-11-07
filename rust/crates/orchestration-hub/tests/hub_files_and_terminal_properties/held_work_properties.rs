use std::collections::BTreeSet;
use std::fs;
use std::os::unix::fs::symlink;
use std::path::PathBuf;

use orchestration_core::identifiers::TaskId;
use orchestration_hub::held_work::{
    HeldWork, TaskBranch, TaskFolder, list_held_work,
};
use orchestration_hub::worktree_roots::WorktreeRoots;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::held_folders::{
    any_slug, any_task_id, create_held_folders, create_task_folder,
    task_folder_name, to_case_error,
};

const FOLDER_CASES: u32 = 24;
const LARGEST_TASK_COUNT: usize = 4;

fn any_held_work() -> impl Strategy<Value = HeldWork> {
    let task_folder = any_task_id().prop_map(|task_id| TaskFolder {
        folder: PathBuf::from("worktrees/task"),
        task_id,
    });
    let task_branch =
        (any_task_id(), any_slug()).prop_map(|(task_id, slug)| TaskBranch {
            cached_clone: PathBuf::from("cache/clone"),
            branch: format!("task/{slug}"),
            task_id,
        });
    (vec(task_folder, 0..5), vec(task_branch, 0..5)).prop_map(
        |(task_folders, task_branches)| HeldWork {
            task_folders,
            task_branches,
        },
    )
}

fn listed_folder_ids(held_work: &HeldWork) -> BTreeSet<TaskId> {
    let mut task_ids = BTreeSet::new();
    for task_folder in &held_work.task_folders {
        task_ids.insert(task_folder.task_id);
    }
    task_ids
}

proptest! {
    #[test]
    fn test_list_task_ids_property_is_the_union_of_both_lists(
        held_work in any_held_work(),
    ) {
        let task_ids = held_work.list_task_ids();

        let mut expected = listed_folder_ids(&held_work);
        for task_branch in &held_work.task_branches {
            expected.insert(task_branch.task_id);
        }
        prop_assert_eq!(task_ids, expected);
    }

    #[test]
    fn test_list_task_ids_property_shared_tasks_are_named_once(
        task_ids in vec(any_task_id(), 0..LARGEST_TASK_COUNT),
    ) {
        let mut held_work = HeldWork::default();
        for task_id in &task_ids {
            held_work.task_folders.push(TaskFolder {
                folder: PathBuf::from("worktrees/task"),
                task_id: *task_id,
            });
            held_work.task_branches.push(TaskBranch {
                cached_clone: PathBuf::from("cache/clone"),
                branch: "task/shared".to_owned(),
                task_id: *task_id,
            });
        }

        let listed = held_work.list_task_ids();

        let expected: BTreeSet<TaskId> = task_ids.into_iter().collect();
        prop_assert_eq!(listed, expected);
    }

    #[test]
    fn test_list_task_ids_property_entry_order_never_matters(
        held_work in any_held_work(),
    ) {
        let mut reversed = held_work.clone();
        reversed.task_folders.reverse();
        reversed.task_branches.reverse();

        prop_assert_eq!(reversed.list_task_ids(), held_work.list_task_ids());
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FOLDER_CASES))]

    #[test]
    fn test_list_held_work_property_missing_roots_hold_nothing(
        cache_name in any_slug(),
        worktrees_name in any_slug(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let roots = WorktreeRoots {
            cache_root: folders.temporary.path().join(cache_name),
            worktrees_root: folders.temporary.path().join(worktrees_name),
        };

        let held_work = list_held_work(&roots).map_err(to_case_error)?;

        prop_assert_eq!(held_work, HeldWork::default());
    }

    #[test]
    fn test_list_held_work_property_listing_changes_nothing(
        tasks in vec((any_slug(), any_task_id()), 0..LARGEST_TASK_COUNT),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let mut created = Vec::new();
        for (slug, task_id) in &tasks {
            let folder_name = task_folder_name(slug, *task_id);
            let worktrees_root = &folders.roots.worktrees_root;
            let folder = create_task_folder(worktrees_root, &folder_name)
                .map_err(to_case_error)?;
            created.push(folder);
        }

        let first = list_held_work(&folders.roots).map_err(to_case_error)?;
        let second = list_held_work(&folders.roots).map_err(to_case_error)?;

        prop_assert_eq!(&first, &second);
        prop_assert!(created.iter().all(|folder| folder.is_dir()));
    }

    #[test]
    fn test_list_task_folders_property_only_task_names_count(
        tasks in vec((any_slug(), any_task_id()), 0..LARGEST_TASK_COUNT),
        other_names in vec("[a-z0-9_-]{1,12}", 0..LARGEST_TASK_COUNT),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let worktrees_root = &folders.roots.worktrees_root;
        for (slug, task_id) in &tasks {
            let folder_name = task_folder_name(slug, *task_id);
            create_task_folder(worktrees_root, &folder_name)
                .map_err(to_case_error)?;
        }
        for other_name in &other_names {
            create_task_folder(worktrees_root, other_name)
                .map_err(to_case_error)?;
        }

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        let expected: BTreeSet<TaskId> =
            tasks.iter().map(|(_slug, task_id)| *task_id).collect();
        prop_assert_eq!(listed_folder_ids(&held_work), expected);
    }

    #[test]
    fn test_list_task_folders_property_run_numbers_name_the_same_task(
        slug in any_slug(),
        task_id in any_task_id(),
        run_number in 1_u32..1000,
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let base_name = task_folder_name(&slug, task_id);
        let folder_name = format!("{base_name}-run-{run_number}");
        let folder =
            create_task_folder(&folders.roots.worktrees_root, &folder_name)
                .map_err(to_case_error)?;

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        let expected = vec![TaskFolder { folder, task_id }];
        prop_assert_eq!(held_work.task_folders, expected);
    }

    #[test]
    fn test_list_task_folders_property_each_folder_keeps_its_path(
        tasks in vec((any_slug(), any_task_id()), 0..LARGEST_TASK_COUNT),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let mut expected = BTreeSet::new();
        for (slug, task_id) in &tasks {
            let folder_name = task_folder_name(slug, *task_id);
            let folder =
                create_task_folder(&folders.roots.worktrees_root, &folder_name)
                    .map_err(to_case_error)?;
            expected.insert((folder, *task_id));
        }

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        let listed: BTreeSet<(PathBuf, TaskId)> = held_work
            .task_folders
            .into_iter()
            .map(|task_folder| (task_folder.folder, task_folder.task_id))
            .collect();
        prop_assert_eq!(listed, expected);
    }

    #[test]
    fn test_is_real_folder_property_linked_task_folders_are_skipped(
        slug in any_slug(),
        task_id in any_task_id(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let outside = create_task_folder(folders.temporary.path(), "outside")
            .map_err(to_case_error)?;
        let worktrees_root = &folders.roots.worktrees_root;
        fs::create_dir_all(worktrees_root).map_err(to_case_error)?;
        let link = worktrees_root.join(task_folder_name(&slug, task_id));
        symlink(&outside, &link).map_err(to_case_error)?;

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        prop_assert_eq!(held_work.task_folders, Vec::new());
        prop_assert!(outside.is_dir());
    }

    #[test]
    fn test_is_real_folder_property_files_are_not_task_folders(
        slug in any_slug(),
        task_id in any_task_id(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let worktrees_root = &folders.roots.worktrees_root;
        fs::create_dir_all(worktrees_root).map_err(to_case_error)?;
        let file = worktrees_root.join(task_folder_name(&slug, task_id));
        fs::write(&file, "not a folder").map_err(to_case_error)?;

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        prop_assert_eq!(held_work.task_folders, Vec::new());
    }

    #[test]
    fn test_is_real_folder_property_empty_task_folders_still_count(
        slug in any_slug(),
        task_id in any_task_id(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let folder = folders
            .roots
            .worktrees_root
            .join(task_folder_name(&slug, task_id));
        fs::create_dir_all(&folder).map_err(to_case_error)?;

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        prop_assert_eq!(
            held_work.task_folders,
            vec![TaskFolder { folder, task_id }],
        );
    }
}

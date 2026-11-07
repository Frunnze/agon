use std::collections::BTreeSet;
use std::fs;
use std::os::unix::fs::symlink;

use orchestration_core::identifiers::TaskId;
use orchestration_hub::held_work::{HeldWork, TaskFolder, list_held_work};
use orchestration_hub::leftover_removal::remove_forgotten_tasks;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::held_folders::{
    any_slug, any_task_id, create_held_folders, create_task_folder,
    task_folder_name, to_case_error,
};

const REMOVAL_CASES: u32 = 24;
const LARGEST_TASK_COUNT: usize = 4;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REMOVAL_CASES))]

    #[test]
    fn test_remove_folder_property_removes_only_forgotten_folders(
        tasks in vec(
            (any_slug(), any_task_id(), any::<bool>()),
            0..LARGEST_TASK_COUNT,
        ),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let mut forgotten_tasks = BTreeSet::new();
        for (slug, task_id, is_forgotten) in &tasks {
            let folder_name = task_folder_name(slug, *task_id);
            create_task_folder(&folders.roots.worktrees_root, &folder_name)
                .map_err(to_case_error)?;
            if *is_forgotten {
                forgotten_tasks.insert(*task_id);
            }
        }
        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        remove_forgotten_tasks(&held_work, &forgotten_tasks)
            .map_err(to_case_error)?;

        for task_folder in &held_work.task_folders {
            let is_forgotten = forgotten_tasks.contains(&task_folder.task_id);
            prop_assert_eq!(task_folder.folder.exists(), !is_forgotten);
        }
    }

    #[test]
    fn test_remove_folder_property_missing_folders_are_already_removed(
        names in vec(any_slug(), 1..LARGEST_TASK_COUNT),
        task_id in any_task_id(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let mut held_work = HeldWork::default();
        for name in &names {
            held_work.task_folders.push(TaskFolder {
                folder: folders.roots.worktrees_root.join(name),
                task_id,
            });
        }
        let forgotten_tasks = BTreeSet::from([task_id]);

        let removed = remove_forgotten_tasks(&held_work, &forgotten_tasks);

        prop_assert!(removed.is_ok(), "{:?}", removed);
    }

    #[test]
    fn test_remove_folder_property_links_go_but_their_targets_stay(
        slug in any_slug(),
        task_id in any_task_id(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let outside = create_task_folder(folders.temporary.path(), "outside")
            .map_err(to_case_error)?;
        fs::create_dir_all(&folders.roots.worktrees_root)
            .map_err(to_case_error)?;
        let link = folders
            .roots
            .worktrees_root
            .join(task_folder_name(&slug, task_id));
        symlink(&outside, &link).map_err(to_case_error)?;
        let held_work = HeldWork {
            task_folders: vec![TaskFolder { folder: link.clone(), task_id }],
            task_branches: Vec::new(),
        };

        remove_forgotten_tasks(&held_work, &BTreeSet::from([task_id]))
            .map_err(to_case_error)?;

        prop_assert!(fs::symlink_metadata(&link).is_err());
        prop_assert!(outside.join("app").join("notes.txt").is_file());
    }

    #[test]
    fn test_remove_folder_property_removing_twice_is_harmless(
        slug in any_slug(),
        task_id in any_task_id(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let folder_name = task_folder_name(&slug, task_id);
        create_task_folder(&folders.roots.worktrees_root, &folder_name)
            .map_err(to_case_error)?;
        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;
        let forgotten_tasks: BTreeSet<TaskId> = BTreeSet::from([task_id]);

        let first = remove_forgotten_tasks(&held_work, &forgotten_tasks);
        let second = remove_forgotten_tasks(&held_work, &forgotten_tasks);

        prop_assert!(first.is_ok() && second.is_ok());
        let listed = list_held_work(&folders.roots).map_err(to_case_error)?;
        prop_assert_eq!(listed, HeldWork::default());
    }
}

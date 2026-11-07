use std::collections::BTreeSet;
use std::fs;
use std::os::unix::fs::symlink;

use orchestration_core::identifiers::TaskId;
use orchestration_hub::held_work::list_held_work;
use orchestration_hub::leftover_removal::{
    remove_forgotten_tasks, remove_unused_clones,
};
use orchestration_hub::worktree_roots::WorktreeRoots;
use proptest::prelude::*;

use crate::git_support::numbered_task_id;
use crate::leftover_support::{
    UNCOMMITTED_FILE, add_detached_worktree, create_origins, create_tasks,
    first_clone_of, list_addresses, prepare_target_runner_folders, roots_of,
};
use crate::target_folders::fail_with;

const REMOVAL_CASES: u32 = 3;
const UNKNOWN_TASK_NUMBER: u128 = 0x9900;
const OUTSIDE_FOLDER_NAME: &str = "outside-worktrees";
const PRECIOUS_FILE: &str = "precious.txt";
const LINKED_ROOT_NAME: &str = "linked-worktrees";

fn any_unusual_name() -> impl Strategy<Value = String> {
    "[a-z][a-zA-Z0-9é中 _.-]{0,10}"
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REMOVAL_CASES))]

    #[test]
    fn test_remove_forgotten_tasks_property_unknown_tasks_change_nothing(
        task_count in 1_usize..3,
        unknown_count in 1_u128..4,
    ) {
        let folders = prepare_target_runner_folders()?;
        let origins = create_origins(&folders)?;
        create_tasks(&folders, &origins, task_count)?;
        let roots = roots_of(&folders);
        let held_before = list_held_work(&roots)
            .map_err(|problem| fail_with(&problem))?;
        let mut unknown_tasks: BTreeSet<TaskId> = BTreeSet::new();
        for offset in 0..unknown_count {
            let task_id = numbered_task_id(UNKNOWN_TASK_NUMBER + offset)
                .map_err(|problem| fail_with(&problem))?;
            unknown_tasks.insert(task_id);
        }

        remove_forgotten_tasks(&held_before, &unknown_tasks)
            .map_err(|problem| fail_with(&problem))?;

        let held_after = list_held_work(&roots)
            .map_err(|problem| fail_with(&problem))?;
        prop_assert_eq!(held_after, held_before);
    }

    #[test]
    fn test_remove_forgotten_tasks_property_repeating_is_harmless(
        task_count in 1_usize..3,
        repeat_count in 1_usize..3,
    ) {
        let folders = prepare_target_runner_folders()?;
        let origins = create_origins(&folders)?;
        let planned_tasks = create_tasks(&folders, &origins, task_count)?;
        let roots = roots_of(&folders);
        let forgotten: BTreeSet<TaskId> =
            BTreeSet::from([planned_tasks[0].task_id]);

        for _ in 0..=repeat_count {
            let held = list_held_work(&roots)
                .map_err(|problem| fail_with(&problem))?;
            remove_forgotten_tasks(&held, &forgotten)
                .map_err(|problem| fail_with(&problem))?;
        }

        let held_after = list_held_work(&roots)
            .map_err(|problem| fail_with(&problem))?;
        prop_assert_eq!(held_after.list_task_ids().len(), task_count - 1);
        prop_assert!(!planned_tasks[0].plan.task_folder.exists());
    }

    #[test]
    fn test_remove_unused_clones_property_used_addresses_keep_everything(
        task_count in 1_usize..3,
        unknown_addresses in proptest::collection::vec("[a-z./]{0,20}", 0..3),
    ) {
        let folders = prepare_target_runner_folders()?;
        let origins = create_origins(&folders)?;
        let planned_tasks = create_tasks(&folders, &origins, task_count)?;
        let roots = roots_of(&folders);
        let addresses_before = list_addresses(&roots.cache_root)?;
        let mut unused = unknown_addresses;
        for address in &addresses_before {
            unused.push(address.to_uppercase());
        }

        remove_unused_clones(&roots, &unused)
            .map_err(|problem| fail_with(&problem))?;

        prop_assert_eq!(list_addresses(&roots.cache_root)?, addresses_before);
        for planned in &planned_tasks {
            for repository in &planned.plan.repositories {
                let note = repository.worktree.join(UNCOMMITTED_FILE);
                prop_assert!(note.exists());
            }
        }
    }

    #[test]
    fn test_remove_unused_clones_property_keeps_worktrees_outside_the_root(
        name in any_unusual_name(),
    ) {
        let folders = prepare_target_runner_folders()?;
        let origins = create_origins(&folders)?;
        let planned_tasks = create_tasks(&folders, &origins, 1)?;
        let roots = roots_of(&folders);
        let clone = first_clone_of(&planned_tasks)?;
        let outside_root = folders.temporary.path().join(OUTSIDE_FOLDER_NAME);
        let outside = outside_root.join(&name);
        add_detached_worktree(&clone, &outside)?;
        let addresses = list_addresses(&roots.cache_root)?;

        remove_unused_clones(&roots, &addresses[..1])
            .map_err(|problem| fail_with(&problem))?;

        prop_assert!(outside.is_dir());
        prop_assert!(!clone.exists());
        prop_assert!(!planned_tasks[0].plan.repositories[0].worktree.exists());
        prop_assert!(planned_tasks[0].plan.repositories[1].worktree.exists());
    }

    #[test]
    fn test_list_linked_worktrees_property_removes_every_linked_worktree(
        task_count in 1_usize..4,
    ) {
        let folders = prepare_target_runner_folders()?;
        let origins = create_origins(&folders)?;
        let planned_tasks = create_tasks(&folders, &origins, task_count)?;
        let roots = roots_of(&folders);
        let addresses = list_addresses(&roots.cache_root)?;

        remove_unused_clones(&roots, &addresses[..1])
            .map_err(|problem| fail_with(&problem))?;

        for planned in &planned_tasks {
            prop_assert!(!planned.plan.repositories[0].worktree.exists());
            prop_assert!(planned.plan.repositories[1].worktree.exists());
        }
        let left_addresses = list_addresses(&roots.cache_root)?;
        prop_assert_eq!(left_addresses, addresses[1..].to_vec());
    }

    #[test]
    fn test_list_linked_worktrees_property_finds_unusual_folder_names(
        names in proptest::collection::btree_set(any_unusual_name(), 1..3),
    ) {
        let folders = prepare_target_runner_folders()?;
        let origins = create_origins(&folders)?;
        let planned_tasks = create_tasks(&folders, &origins, 1)?;
        let roots = roots_of(&folders);
        let clone = first_clone_of(&planned_tasks)?;
        let mut added = Vec::new();
        for name in &names {
            let worktree = roots.worktrees_root.join(format!("extra {name}"));
            add_detached_worktree(&clone, &worktree)?;
            added.push(worktree);
        }
        let addresses = list_addresses(&roots.cache_root)?;

        remove_unused_clones(&roots, &addresses[..1])
            .map_err(|problem| fail_with(&problem))?;

        for worktree in &added {
            prop_assert!(!worktree.exists(), "{}", worktree.display());
        }
    }

    #[test]
    fn test_list_linked_worktrees_property_skips_worktrees_already_gone(
        task_count in 1_usize..3,
    ) {
        let folders = prepare_target_runner_folders()?;
        let origins = create_origins(&folders)?;
        let planned_tasks = create_tasks(&folders, &origins, task_count)?;
        let roots = roots_of(&folders);
        fs::remove_dir_all(&planned_tasks[0].plan.repositories[0].worktree)
            .map_err(|problem| fail_with(&problem))?;
        let addresses = list_addresses(&roots.cache_root)?;

        remove_unused_clones(&roots, &addresses[..1])
            .map_err(|problem| fail_with(&problem))?;

        let left_addresses = list_addresses(&roots.cache_root)?;
        prop_assert_eq!(left_addresses, addresses[1..].to_vec());
    }

    #[test]
    fn test_is_inside_folder_property_keeps_sibling_folders_with_like_names(
        suffix in "[a-z0-9-]{1,6}",
    ) {
        let folders = prepare_target_runner_folders()?;
        let origins = create_origins(&folders)?;
        let planned_tasks = create_tasks(&folders, &origins, 1)?;
        let roots = roots_of(&folders);
        let clone = first_clone_of(&planned_tasks)?;
        let root_text = roots.worktrees_root.display();
        let sibling_root = format!("{root_text}{suffix}");
        let sibling = std::path::PathBuf::from(sibling_root).join("kept");
        add_detached_worktree(&clone, &sibling)?;
        let addresses = list_addresses(&roots.cache_root)?;

        remove_unused_clones(&roots, &addresses[..1])
            .map_err(|problem| fail_with(&problem))?;

        prop_assert!(sibling.is_dir());
    }

    #[test]
    fn test_is_inside_folder_property_reads_the_root_through_links(
        task_count in 1_usize..3,
    ) {
        let folders = prepare_target_runner_folders()?;
        let origins = create_origins(&folders)?;
        let planned_tasks = create_tasks(&folders, &origins, task_count)?;
        let linked_root = folders.temporary.path().join(LINKED_ROOT_NAME);
        symlink(&folders.worktrees_root, &linked_root)
            .map_err(|problem| fail_with(&problem))?;
        let roots = WorktreeRoots {
            cache_root: folders.cache_root.clone(),
            worktrees_root: linked_root,
        };
        let addresses = list_addresses(&roots.cache_root)?;

        remove_unused_clones(&roots, &addresses[..1])
            .map_err(|problem| fail_with(&problem))?;

        for planned in &planned_tasks {
            prop_assert!(!planned.plan.repositories[0].worktree.exists());
        }
    }

    #[test]
    fn test_is_inside_folder_property_never_follows_a_swapped_in_link(
        precious_text in "[a-z ]{1,20}",
    ) {
        let folders = prepare_target_runner_folders()?;
        let origins = create_origins(&folders)?;
        let planned_tasks = create_tasks(&folders, &origins, 1)?;
        let roots = roots_of(&folders);
        let temporary = folders.temporary.path();
        let precious_folder = temporary.join(OUTSIDE_FOLDER_NAME);
        fs::create_dir_all(&precious_folder)
            .map_err(|problem| fail_with(&problem))?;
        let precious_file = precious_folder.join(PRECIOUS_FILE);
        fs::write(&precious_file, &precious_text)
            .map_err(|problem| fail_with(&problem))?;
        let worktree = &planned_tasks[0].plan.repositories[0].worktree;
        fs::remove_dir_all(worktree).map_err(|problem| fail_with(&problem))?;
        symlink(&precious_folder, worktree)
            .map_err(|problem| fail_with(&problem))?;
        let addresses = list_addresses(&roots.cache_root)?;

        remove_unused_clones(&roots, &addresses[..1])
            .map_err(|problem| fail_with(&problem))?;

        let kept_text =
            fs::read_to_string(&precious_file)
                .map_err(|problem| fail_with(&problem))?;
        prop_assert_eq!(kept_text, precious_text);
    }
}

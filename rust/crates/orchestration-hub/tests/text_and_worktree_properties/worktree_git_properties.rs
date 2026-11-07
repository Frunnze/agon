use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};

use orchestration_hub::cached_clones::cached_clone_folder;
use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::held_work::{HeldWork, TaskBranch, list_held_work};
use orchestration_hub::leftover_removal::remove_forgotten_tasks;
use orchestration_hub::workspace_mounts::GIT_DIRECTORY_NAME;
use orchestration_hub::worktree_plan::WorktreeLifetime;
use orchestration_hub::worktree_roots::WorktreeRoots;
use orchestration_hub::worktrees::{
    WorktreeError, delete_task_branches, remove_worktrees,
};
use proptest::prelude::*;

use crate::held_folders::{
    TASK_BRANCH_PREFIX, any_address, any_slug, any_task_id,
    create_cached_clone, create_held_folders, task_folder_name, to_case_error,
};
use crate::worktree_folders::{
    CaseResult, GIT_CASES, branch_exists, create, create_origins, git,
    plan_task, prepare_folders,
};
use crate::worktree_support::any_hostile_title;

const ENCLOSING_FOLDER_NAME: &str = "enclosing";
const BRANCH_LISTING_PROGRAM: &str = "for-each-ref";
const TASK_NUMBER: u128 = 0x5555_0000_0000_4000_8000_0000_0000_0005;

fn create_enclosing_repository(
    folder: &Path,
    branch: &str,
) -> CaseResult<PathBuf> {
    let enclosing = folder.join(ENCLOSING_FOLDER_NAME);
    fs::create_dir_all(&enclosing).map_err(to_case_error)?;
    git(&enclosing, &["init", "--quiet", "--initial-branch=main"])?;
    git(
        &enclosing,
        &["commit", "--quiet", "--allow-empty", "-m", "Start"],
    )?;
    git(&enclosing, &["branch", branch])?;
    Ok(enclosing)
}

fn roots_inside(folder: &Path) -> WorktreeRoots {
    WorktreeRoots {
        cache_root: folder.join("cache"),
        worktrees_root: folder.join("worktrees"),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_read_git_output_property_lists_the_task_branches_git_holds(
        address in any_address(),
        tasks in
            proptest::collection::btree_map(any_task_id(), any_slug(), 0..4),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let mut branches = Vec::new();
        for (task_id, slug) in &tasks {
            let name = task_folder_name(slug, *task_id);
            branches.push(format!("{TASK_BRANCH_PREFIX}{name}"));
        }
        create_cached_clone(&folders.roots.cache_root, &address, &branches)
            .map_err(to_case_error)?;

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        let listed: BTreeSet<String> = held_work.task_branches.iter()
            .map(|task_branch| task_branch.branch.clone()).collect();
        let expected: BTreeSet<String> = branches.into_iter().collect();
        prop_assert_eq!(listed, expected);
    }

    #[test]
    fn test_read_git_output_property_never_reads_an_enclosing_repository(
        address in any_address(),
        task_id in any_task_id(),
        slug in any_slug(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let branch = format!(
            "{TASK_BRANCH_PREFIX}{}",
            task_folder_name(&slug, task_id)
        );
        let enclosing =
            create_enclosing_repository(folders.temporary.path(), &branch)?;
        let roots = roots_inside(&enclosing);
        let clone = cached_clone_folder(&roots.cache_root, &address);
        fs::create_dir_all(clone.join(GIT_DIRECTORY_NAME))
            .map_err(to_case_error)?;

        let listing = list_held_work(&roots);

        let Err(WorktreeError::GitFailed { arguments, output }) = listing
        else {
            return Err(to_case_error(format!("{listing:?}")));
        };
        prop_assert!(
            arguments.starts_with(BRANCH_LISTING_PROGRAM),
            "{}",
            arguments
        );
        prop_assert!(!output.is_empty());
        prop_assert_eq!(output.trim(), output.as_str());
    }

    #[test]
    fn test_read_git_output_property_unusual_branch_names_come_back_exactly(
        address in any_address(),
        tasks in proptest::collection::btree_map(
            any_task_id(),
            "[a-z][a-zé中ü+@_#]{0,6}",
            1..4,
        ),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let mut branches = BTreeSet::new();
        for (task_id, readable_part) in &tasks {
            let name = task_folder_name(readable_part, *task_id);
            branches.insert(format!("{TASK_BRANCH_PREFIX}{name}"));
        }
        let branch_list: Vec<String> = branches.iter().cloned().collect();
        create_cached_clone(&folders.roots.cache_root, &address, &branch_list)
            .map_err(to_case_error)?;

        let held_work = list_held_work(&folders.roots).map_err(to_case_error)?;

        let listed: BTreeSet<String> = held_work.task_branches.iter()
            .map(|task_branch| task_branch.branch.clone()).collect();
        prop_assert_eq!(listed, branches);
        let listed_ids: BTreeSet<_> = held_work.task_branches.iter()
            .map(|task_branch| task_branch.task_id).collect();
        let expected_ids: BTreeSet<_> = tasks.keys().copied().collect();
        prop_assert_eq!(listed_ids, expected_ids);
    }

    #[test]
    fn test_worktrees_run_git_property_deletes_the_branch_it_names(
        title in any_hostile_title(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan = plan_task(
            &folders,
            TASK_NUMBER,
            &title,
            WorktreeLifetime::PerTask,
            &origins,
        )?;
        create(&plan)?;
        let cached_clone = &plan.repositories[0].cached_clone;
        let clone_locks = CloneLocks::default();
        remove_worktrees(&plan, &clone_locks).map_err(to_case_error)?;

        delete_task_branches(&plan, &clone_locks).map_err(to_case_error)?;

        prop_assert!(!branch_exists(cached_clone, &plan.branch)?);
        let remote_main =
            git(cached_clone, &["rev-parse", "--verify", "origin/main"]);
        prop_assert!(remote_main.is_ok(), "{:?}", remote_main);
    }

    #[test]
    fn test_worktrees_run_git_property_failures_carry_git_message(
        title in any_hostile_title(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan = plan_task(
            &folders,
            TASK_NUMBER,
            &title,
            WorktreeLifetime::PerTask,
            &origins,
        )?;
        create(&plan)?;

        let deletion = delete_task_branches(&plan, &CloneLocks::default());

        let Err(WorktreeError::GitFailed { arguments, output }) = deletion
        else {
            return Err(to_case_error(format!("{deletion:?}")));
        };
        prop_assert_eq!(arguments, format!("branch -D {}", plan.branch));
        prop_assert!(output.contains(&plan.branch), "{}", output);
        prop_assert_eq!(output.trim(), output.as_str());
    }

    #[test]
    fn test_worktrees_run_git_property_never_touches_an_enclosing_repository(
        address in any_address(),
        task_id in any_task_id(),
        slug in any_slug(),
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let branch = format!(
            "{TASK_BRANCH_PREFIX}{}",
            task_folder_name(&slug, task_id)
        );
        let enclosing =
            create_enclosing_repository(folders.temporary.path(), &branch)?;
        let clone = cached_clone_folder(
            &roots_inside(&enclosing).cache_root,
            &address,
        );
        fs::create_dir_all(clone.join(GIT_DIRECTORY_NAME))
            .map_err(to_case_error)?;
        let held_work = HeldWork {
            task_folders: Vec::new(),
            task_branches: vec![TaskBranch {
                cached_clone: clone,
                branch: branch.clone(),
                task_id,
            }],
        };

        let removal =
            remove_forgotten_tasks(&held_work, &BTreeSet::from([task_id]));

        prop_assert!(removal.is_err());
        prop_assert!(branch_exists(&enclosing, &branch)?);
    }
}

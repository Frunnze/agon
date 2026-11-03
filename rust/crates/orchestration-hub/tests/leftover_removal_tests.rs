mod git_support;

use std::collections::BTreeSet;
use std::fmt::Display;
use std::fs;
use std::path::{Path, PathBuf};

use git_support::{
    RunnerFolders, TestResult, create_origin, numbered_task_id, plan_for,
    prepare_runner_folders, run_git,
};
use orchestration_core::identifiers::TaskId;
use orchestration_hub::cached_clones::list_cached_repositories;
use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::held_work::list_held_work;
use orchestration_hub::leftover_removal::{
    remove_forgotten_tasks, remove_unused_clones,
};
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreePlan};
use orchestration_hub::worktree_roots::WorktreeRoots;
use orchestration_hub::worktrees::create_worktrees;
use proptest::collection::vec;
use proptest::prelude::*;

const REMOVAL_CASES: u32 = 6;
const FIRST_TASK_NUMBER: u128 = 0x5100;
const UNCOMMITTED_FILE: &str = "notes.txt";
const ORIGIN_NAMES: [&str; 2] = ["app", "site"];

struct PlannedTask {
    task_id: TaskId,
    plan: WorktreePlan,
}

fn to_case_error(problem: impl Display) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

fn roots_of(folders: &RunnerFolders) -> WorktreeRoots {
    WorktreeRoots {
        cache_root: folders.cache_root.clone(),
        worktrees_root: folders.worktrees_root.clone(),
    }
}

fn lifetime_for(is_job: bool, number: u32) -> WorktreeLifetime {
    if is_job {
        return WorktreeLifetime::PerJobRun { run_number: number };
    }
    WorktreeLifetime::PerTask
}

fn create_tasks(
    folders: &RunnerFolders,
    origins: &[PathBuf],
    job_flags: &[bool],
) -> TestResult<Vec<PlannedTask>> {
    let clone_locks = CloneLocks::default();
    let mut planned_tasks = Vec::new();
    for (position, is_job) in job_flags.iter().enumerate() {
        let offset = u128::try_from(position)?;
        let task_id = numbered_task_id(FIRST_TASK_NUMBER + offset)?;
        let run_number = u32::try_from(position)? + 1;
        let lifetime = lifetime_for(*is_job, run_number);
        let title = format!("Task number {position}");
        let plan = plan_for(folders, task_id, &title, lifetime, origins)?;
        create_worktrees(&plan, &clone_locks)?;
        for repository in &plan.repositories {
            let note = repository.worktree.join(UNCOMMITTED_FILE);
            fs::write(note, "work in progress")?;
        }
        planned_tasks.push(PlannedTask { task_id, plan });
    }
    Ok(planned_tasks)
}

fn create_origins(folders: &RunnerFolders) -> TestResult<Vec<PathBuf>> {
    let mut origins = Vec::new();
    for name in ORIGIN_NAMES {
        origins.push(create_origin(folders, name)?);
    }
    Ok(origins)
}

fn branch_exists(clone: &Path, branch: &str) -> bool {
    let reference = format!("refs/heads/{branch}");
    run_git(clone, &["rev-parse", "--verify", "--quiet", &reference]).is_ok()
}

fn is_task_kept_whole(planned: &PlannedTask) -> bool {
    planned.plan.repositories.iter().all(|repository| {
        let note = repository.worktree.join(UNCOMMITTED_FILE);
        note.exists()
            && branch_exists(&repository.cached_clone, &planned.plan.branch)
    })
}

fn is_task_gone(planned: &PlannedTask) -> bool {
    let has_branch = planned.plan.repositories.iter().any(|repository| {
        branch_exists(&repository.cached_clone, &planned.plan.branch)
    });
    !planned.plan.task_folder.exists() && !has_branch
}

fn origin_branches(origin: &Path) -> TestResult<String> {
    run_git(origin, &["for-each-ref", "--format=%(refname)"])
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REMOVAL_CASES))]

    #[test]
    fn test_list_held_work_property_names_every_task_on_disk(
        job_flags in vec(any::<bool>(), 0..4),
    ) {
        let folders = prepare_runner_folders().map_err(to_case_error)?;
        let origins = create_origins(&folders).map_err(to_case_error)?;
        let planned_tasks = create_tasks(&folders, &origins, &job_flags)
            .map_err(to_case_error)?;
        let roots = roots_of(&folders);

        let held_work = list_held_work(&roots).map_err(to_case_error)?;

        let expected: BTreeSet<TaskId> =
            planned_tasks.iter().map(|planned| planned.task_id).collect();
        prop_assert_eq!(held_work.list_task_ids(), expected);
        prop_assert_eq!(held_work.task_folders.len(), job_flags.len());
        let branch_count = job_flags.len() * ORIGIN_NAMES.len();
        prop_assert_eq!(held_work.task_branches.len(), branch_count);
    }

    #[test]
    fn test_remove_forgotten_tasks_property_removes_only_forgotten_work(
        flags in vec((any::<bool>(), any::<bool>()), 1..4),
    ) {
        let folders = prepare_runner_folders().map_err(to_case_error)?;
        let origins = create_origins(&folders).map_err(to_case_error)?;
        let job_flags: Vec<bool> = flags.iter().map(|flag| flag.1).collect();
        let planned_tasks = create_tasks(&folders, &origins, &job_flags)
            .map_err(to_case_error)?;
        let origin_refs_before =
            origin_branches(&origins[0]).map_err(to_case_error)?;
        let mut forgotten = BTreeSet::new();
        for (planned, (is_forgotten, _)) in planned_tasks.iter().zip(&flags) {
            if *is_forgotten {
                forgotten.insert(planned.task_id);
            }
        }
        let roots = roots_of(&folders);
        let held_work = list_held_work(&roots).map_err(to_case_error)?;

        remove_forgotten_tasks(&held_work, &forgotten).map_err(to_case_error)?;

        for planned in &planned_tasks {
            if forgotten.contains(&planned.task_id) {
                prop_assert!(is_task_gone(planned));
            } else {
                prop_assert!(is_task_kept_whole(planned));
            }
        }
        let origin_refs_after =
            origin_branches(&origins[0]).map_err(to_case_error)?;
        prop_assert_eq!(origin_refs_after, origin_refs_before);
        let held_after = list_held_work(&roots).map_err(to_case_error)?;
        prop_assert!(held_after.list_task_ids().is_disjoint(&forgotten));
    }

    #[test]
    fn test_remove_unused_clones_property_removes_only_unused_copies(
        unused_flags in vec(any::<bool>(), ORIGIN_NAMES.len()),
    ) {
        let folders = prepare_runner_folders().map_err(to_case_error)?;
        let origins = create_origins(&folders).map_err(to_case_error)?;
        let planned_tasks = create_tasks(&folders, &origins, &[false])
            .map_err(to_case_error)?;
        let roots = roots_of(&folders);
        let cached_addresses = list_cached_repositories(&roots.cache_root)
            .map_err(to_case_error)?;
        let mut unused_addresses = Vec::new();
        for (address, is_unused) in cached_addresses.iter().zip(&unused_flags)
        {
            if *is_unused {
                unused_addresses.push(address.clone());
            }
        }
        unused_addresses.push(String::new());
        unused_addresses.push("github.com/acme/never-cloned".to_owned());

        remove_unused_clones(&roots, &unused_addresses)
            .map_err(to_case_error)?;

        let left_addresses = list_cached_repositories(&roots.cache_root)
            .map_err(to_case_error)?;
        let repositories = &planned_tasks[0].plan.repositories;
        for (repository, is_unused) in repositories.iter().zip(&unused_flags) {
            prop_assert_eq!(repository.cached_clone.exists(), !is_unused);
            prop_assert_eq!(repository.worktree.exists(), !is_unused);
        }
        let kept_count = unused_flags.iter().filter(|flag| !**flag).count();
        prop_assert_eq!(left_addresses.len(), kept_count);
        for origin in &origins {
            prop_assert!(origin.join("README.md").exists());
        }
        prop_assert!(roots.cache_root.exists());
        prop_assert!(roots.worktrees_root.exists());
    }
}

#[test]
fn leaves_folders_that_are_not_task_folders_alone() -> TestResult<()> {
    let folders = prepare_runner_folders()?;
    let roots = roots_of(&folders);
    let stranger = roots.worktrees_root.join("my-own-folder");
    fs::create_dir_all(&stranger)?;

    let held_work = list_held_work(&roots)?;

    assert!(held_work.list_task_ids().is_empty());
    assert!(stranger.exists());
    Ok(())
}

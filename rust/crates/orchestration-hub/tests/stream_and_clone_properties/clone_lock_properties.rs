use std::fs;
use std::path::PathBuf;
use std::sync::mpsc;
use std::sync::{Arc, Barrier};
use std::thread;
use std::time::Duration;

use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreePlan};
use orchestration_hub::worktrees::{
    WorktreeOrigin, create_worktrees, delete_task_branches, remove_worktrees,
};
use proptest::prelude::*;

use crate::git_support::{
    RunnerFolders, create_origin, numbered_task_id, plan_for,
    prepare_runner_folders,
};

const GIT_CASES: u32 = 3;
const TIME_LIMIT: Duration = Duration::from_secs(60);
const README_NAME: &str = "README.md";

type WorkOutcome = Result<(), String>;

fn fail(problem: &impl ToString) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

fn prepare_folders() -> Result<RunnerFolders, TestCaseError> {
    prepare_runner_folders().map_err(|problem| fail(&problem))
}

fn plan_tasks(
    folders: &RunnerFolders,
    task_count: u128,
    origins: &[PathBuf],
) -> Result<Vec<WorktreePlan>, TestCaseError> {
    let mut plans = Vec::new();
    for number in 0..task_count {
        let task_id =
            numbered_task_id(number + 1).map_err(|problem| fail(&problem))?;
        let lifetime = WorktreeLifetime::PerTask;
        let plan = plan_for(folders, task_id, "Task", lifetime, origins)
            .map_err(|problem| fail(&problem))?;
        plans.push(plan);
    }
    Ok(plans)
}

fn create_origins(
    folders: &RunnerFolders,
    origin_count: usize,
) -> Result<Vec<PathBuf>, TestCaseError> {
    let mut origins = Vec::new();
    for number in 0..origin_count {
        let origin = create_origin(folders, &format!("app{number}"))
            .map_err(|problem| fail(&problem))?;
        origins.push(origin);
    }
    Ok(origins)
}

fn create_one(plan: &WorktreePlan, clone_locks: &CloneLocks) -> WorkOutcome {
    create_worktrees(plan, clone_locks)
        .map(|_prepared| ())
        .map_err(|problem| problem.to_string())
}

fn clean_up_one(plan: &WorktreePlan, clone_locks: &CloneLocks) -> WorkOutcome {
    remove_worktrees(plan, clone_locks)
        .map_err(|problem| problem.to_string())?;
    delete_task_branches(plan, clone_locks)
        .map_err(|problem| problem.to_string())
}

fn create_after_barrier(
    plan: &WorktreePlan,
    clone_locks: &CloneLocks,
    start_together: &Barrier,
) -> WorkOutcome {
    start_together.wait();
    create_one(plan, clone_locks)
}

fn create_together(
    plans: &[WorktreePlan],
    clone_locks: &Arc<CloneLocks>,
) -> Vec<WorkOutcome> {
    let start_together = Arc::new(Barrier::new(plans.len()));
    let mut workers = Vec::new();
    for plan in plans {
        let plan = plan.clone();
        let clone_locks = Arc::clone(clone_locks);
        let start_together = Arc::clone(&start_together);
        workers.push(thread::spawn(move || {
            create_after_barrier(&plan, &clone_locks, &start_together)
        }));
    }

    let mut outcomes = Vec::new();
    for worker in workers {
        let outcome = worker
            .join()
            .unwrap_or_else(|_| Err("a worker panicked".to_owned()));
        outcomes.push(outcome);
    }
    outcomes
}

fn finish_in_time(
    work: impl FnOnce() -> WorkOutcome + Send + 'static,
) -> Result<WorkOutcome, TestCaseError> {
    let (sender, receiver) = mpsc::channel();
    thread::spawn(move || sender.send(work()));
    receiver
        .recv_timeout(TIME_LIMIT)
        .map_err(|_| TestCaseError::fail("the work waited on a held lock"))
}

fn has_readme(plan: &WorktreePlan) -> bool {
    plan.repositories
        .iter()
        .all(|repository| repository.worktree.join(README_NAME).exists())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_lock_for_property_parallel_tasks_of_one_clone_all_succeed(
        task_count in 2_u128..5,
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plans = plan_tasks(&folders, task_count, &origins)?;

        let outcomes = create_together(&plans, &Arc::default());

        for (plan, outcome) in plans.iter().zip(&outcomes) {
            prop_assert_eq!(outcome, &Ok(()));
            prop_assert!(has_readme(plan));
        }
    }

    #[test]
    fn test_lock_for_property_parallel_tasks_of_many_clones_all_succeed(
        task_count in 2_u128..4,
        origin_count in 2_usize..4,
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, origin_count)?;
        let plans = plan_tasks(&folders, task_count, &origins)?;

        let outcomes = create_together(&plans, &Arc::default());

        for (plan, outcome) in plans.iter().zip(&outcomes) {
            prop_assert_eq!(outcome, &Ok(()));
            prop_assert!(has_readme(plan));
        }
    }

    #[test]
    fn test_lock_for_property_cleanup_and_creation_share_a_clone(
        task_count in 2_u128..4,
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plans = plan_tasks(&folders, task_count, &origins)?;
        let clone_locks = Arc::new(CloneLocks::default());
        let (finished_plan, new_plans) = plans.split_at(1);
        create_one(&finished_plan[0], &clone_locks)
            .map_err(|problem| fail(&problem))?;

        let cleaned_plan = finished_plan[0].clone();
        let cleaning_locks = Arc::clone(&clone_locks);
        let cleaner = thread::spawn(move || {
            clean_up_one(&cleaned_plan, &cleaning_locks)
        });
        let outcomes = create_together(new_plans, &clone_locks);
        let cleaned = cleaner.join().unwrap_or_else(|_| Err("panic".into()));

        prop_assert_eq!(cleaned, Ok(()));
        prop_assert!(!finished_plan[0].task_folder.exists());
        for (plan, outcome) in new_plans.iter().zip(&outcomes) {
            prop_assert_eq!(outcome, &Ok(()));
            prop_assert!(has_readme(plan));
        }
    }

    #[test]
    fn test_hold_lock_property_repeated_cycles_never_wait_forever(
        cycle_count in 1_usize..4,
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan = plan_tasks(&folders, 1, &origins)?.remove(0);
        let clone_locks = Arc::new(CloneLocks::default());

        for _ in 0..cycle_count {
            let created_plan = plan.clone();
            let creating_locks = Arc::clone(&clone_locks);
            let created = finish_in_time(move || {
                create_one(&created_plan, &creating_locks)
            })?;
            let cleaned_plan = plan.clone();
            let cleaning_locks = Arc::clone(&clone_locks);
            let cleaned = finish_in_time(move || {
                clean_up_one(&cleaned_plan, &cleaning_locks)
            })?;

            prop_assert_eq!(created, Ok(()));
            prop_assert_eq!(cleaned, Ok(()));
        }
    }

    #[test]
    fn test_hold_lock_property_failed_steps_release_the_clone(
        blocker_text in "[a-z ]{0,12}",
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan = plan_tasks(&folders, 1, &origins)?.remove(0);
        let worktree = plan.repositories[0].worktree.clone();
        fs::create_dir_all(&plan.task_folder)
            .map_err(|problem| fail(&problem))?;
        fs::write(&worktree, blocker_text).map_err(|problem| fail(&problem))?;
        let clone_locks = Arc::new(CloneLocks::default());

        let blocked = create_one(&plan, &clone_locks);
        fs::remove_file(&worktree).map_err(|problem| fail(&problem))?;
        let retried_plan = plan.clone();
        let retried = finish_in_time(move || {
            create_one(&retried_plan, &clone_locks)
        })?;

        prop_assert!(blocked.is_err());
        prop_assert_eq!(retried, Ok(()));
        prop_assert!(has_readme(&plan));
    }

    #[test]
    fn test_hold_lock_property_second_creation_reuses_the_worktree(
        task_count in 1_u128..3,
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plans = plan_tasks(&folders, task_count, &origins)?;
        let clone_locks = CloneLocks::default();

        for plan in &plans {
            let first = create_worktrees(plan, &clone_locks)
                .map_err(|problem| fail(&problem))?;
            let second = create_worktrees(plan, &clone_locks)
                .map_err(|problem| fail(&problem))?;

            let first_origin = first.worktrees[0].origin;
            let second_origin = second.worktrees[0].origin;
            prop_assert_eq!(first_origin, WorktreeOrigin::Created);
            prop_assert_eq!(second_origin, WorktreeOrigin::Reused);
        }
    }
}

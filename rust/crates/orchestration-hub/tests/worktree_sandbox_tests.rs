mod git_support;

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Barrier};
use std::thread;

use git_support::{
    TestResult, create_origin, numbered_task_id, plan_for,
    prepare_runner_folders,
};
use orchestration_core::device::SandboxKind;
use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::sandbox::{
    ContainerEngine, ContainerSettings, wrap_in_sandbox,
};
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreePlan};
use orchestration_hub::worktrees::{PreparedWorkspace, create_worktrees};
use proptest::prelude::*;

const PARALLEL_TASKS: u128 = 6;
const GIT_POINTER_PREFIX: &str = "gitdir: ";

#[derive(Debug)]
struct SandboxedTask {
    mount_values: Vec<String>,
    expected_mount_values: Vec<String>,
    worktree_pointers: Vec<PathBuf>,
    git_directories: Vec<PathBuf>,
}

fn agent_command() -> CommandSpecification {
    CommandSpecification {
        program: "claude".to_string(),
        arguments: vec!["-p".to_string()],
        environment: BTreeMap::new(),
        working_directory: None,
    }
}

fn container_settings() -> ContainerSettings {
    ContainerSettings {
        engine: ContainerEngine::Docker,
        image: "agents/runner".to_string(),
    }
}

fn mount_values(arguments: &[String]) -> Vec<String> {
    let mut values = Vec::new();
    for pair in arguments.windows(2) {
        if pair[0] == "--mount" {
            values.push(pair[1].clone());
        }
    }
    values
}

fn bind_mount(source: &Path, target: &str) -> String {
    format!("type=bind,source={},target={target}", source.display())
}

fn sandbox_new_task(
    title: &str,
    repository_count: usize,
) -> TestResult<SandboxedTask> {
    let folders = prepare_runner_folders()?;
    let mut origins = Vec::new();
    for index in 0..repository_count {
        let name = format!("repository-{index}");
        origins.push(create_origin(&folders, &name)?);
    }
    let task_id = numbered_task_id(1)?;
    let lifetime = WorktreeLifetime::PerTask;
    let plan = plan_for(&folders, task_id, title, lifetime, &origins)?;
    let prepared = create_worktrees(&plan, &CloneLocks::default())?;

    let real_task_folder = plan.task_folder.canonicalize()?;
    let mut expected_mount_values =
        vec![bind_mount(&real_task_folder, "/workspace")];
    let mut git_directories = Vec::new();
    let mut worktree_pointers = Vec::new();
    for repository in &plan.repositories {
        let git_directory = repository.cached_clone.join(".git");
        let real_git_directory = git_directory.canonicalize()?;
        let shown = real_git_directory.display().to_string();
        expected_mount_values.push(bind_mount(&real_git_directory, &shown));
        git_directories.push(real_git_directory);

        let pointer = fs::read_to_string(repository.worktree.join(".git"))?;
        let target = pointer
            .trim()
            .strip_prefix(GIT_POINTER_PREFIX)
            .ok_or("the worktree has no git pointer")?;
        worktree_pointers.push(PathBuf::from(target));
    }

    let wrapped = wrap_in_sandbox(
        SandboxKind::Container,
        &container_settings(),
        &agent_command(),
        &prepared.mounts,
        &[],
    )?;
    Ok(SandboxedTask {
        mount_values: mount_values(&wrapped.arguments),
        expected_mount_values,
        worktree_pointers,
        git_directories,
    })
}

fn create_after_barrier(
    plan: &WorktreePlan,
    clone_locks: &CloneLocks,
    start_together: &Barrier,
) -> Result<PreparedWorkspace, String> {
    start_together.wait();
    create_worktrees(plan, clone_locks).map_err(|problem| problem.to_string())
}

#[test]
fn creates_worktrees_for_parallel_tasks_of_one_repository() -> TestResult<()> {
    let folders = prepare_runner_folders()?;
    let origin = create_origin(&folders, "app")?;
    let lifetime = WorktreeLifetime::PerTask;
    let mut plans = Vec::new();
    for number in 0..PARALLEL_TASKS {
        let task_id = numbered_task_id(number)?;
        let origins = [origin.clone()];
        plans.push(plan_for(&folders, task_id, "Task", lifetime, &origins)?);
    }

    let clone_locks = Arc::new(CloneLocks::default());
    let start_together = Arc::new(Barrier::new(plans.len()));
    let mut workers = Vec::new();
    for plan in plans.clone() {
        let clone_locks = Arc::clone(&clone_locks);
        let start_together = Arc::clone(&start_together);
        workers.push(thread::spawn(move || {
            create_after_barrier(&plan, &clone_locks, &start_together)
        }));
    }
    let mut outcomes = Vec::new();
    for worker in workers {
        outcomes.push(worker.join().map_err(|_| "a worker panicked")?);
    }

    let mut branches = BTreeSet::new();
    for (plan, outcome) in plans.iter().zip(&outcomes) {
        assert!(outcome.is_ok(), "{outcome:?}");
        assert!(plan.repositories[0].worktree.join("README.md").exists());
        branches.insert(plan.branch.clone());
    }
    assert_eq!(branches.len(), plans.len());
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_create_worktrees_property_mounts_only_task_and_git_folders(
        title in "[a-zA-Z][a-zA-Z ]{0,19}",
        repository_count in 1_usize..4,
    ) {
        let sandboxed = sandbox_new_task(&title, repository_count)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(
            &sandboxed.mount_values,
            &sandboxed.expected_mount_values,
        );
        for pointer in &sandboxed.worktree_pointers {
            let is_inside_a_mounted_git_folder = sandboxed
                .git_directories
                .iter()
                .any(|git_directory| pointer.starts_with(git_directory));
            prop_assert!(is_inside_a_mounted_git_folder);
        }
    }
}

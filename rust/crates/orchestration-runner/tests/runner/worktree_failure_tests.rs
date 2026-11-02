use std::fs;
use std::os::unix::fs::symlink;
use std::sync::Arc;

use orchestration_api::work::RunAssignment;
use orchestration_core::run::StepStatus;
use orchestration_core::task::{Schedule, Task};
use orchestration_core::workspace::{AgentAccess, Repository};
use orchestration_runner::agent_run_executor::AgentRunExecutor;
use orchestration_runner::branch_pusher::GitBranchPusher;
use orchestration_runner::run_executor::{RunExecutor, RunOutcome};
use orchestration_runner::runner_configuration::RunnerConfiguration;
use proptest::option;
use proptest::prelude::*;
use tokio::runtime::Runtime;

use crate::assignments::{assignment_for, claude_task};
use crate::event_queries::{branches, failures, step_statuses};
use crate::executor_support::{RUN_NUMBER, STEP_NAME};
use crate::fake_agent::{
    AgentFolders, has_agent_records, local_configuration,
    prepare_agent_folders,
};
use crate::fake_server::FakeServer;
use crate::git_support::{create_bare_origin, origins_folder, repository_at};
use crate::mix_execution::plan_task_folder;
use crate::support::{TestResult, to_case_error};

const REPOSITORY_NAME: &str = "app";
const MISSING_ORIGIN: &str = "local.test/acme/missing.git";
const BLOCKING_FILE_CONTENT: &str = "not a folder";
const REASON_START: &str = "could not create the worktree";
const JOB_SCHEDULE: Schedule = Schedule::Hour { minute: 0 };
const MAXIMUM_ATTEMPTS: usize = 2;

#[derive(Clone, Copy, Debug)]
enum WorktreeObstacle {
    MissingCloneSource,
    FileAtTaskFolder,
    LinkToCacheAtTaskFolder,
    LinkToCacheAtRepositoryWorktree,
}

fn any_obstacle() -> impl Strategy<Value = WorktreeObstacle> {
    prop_oneof![
        Just(WorktreeObstacle::MissingCloneSource),
        Just(WorktreeObstacle::FileAtTaskFolder),
        Just(WorktreeObstacle::LinkToCacheAtTaskFolder),
        Just(WorktreeObstacle::LinkToCacheAtRepositoryWorktree),
    ]
}

fn choose_repository(
    folders: &AgentFolders,
    obstacle: WorktreeObstacle,
) -> TestResult<Repository> {
    let temporary = folders.temporary.path();
    if let WorktreeObstacle::MissingCloneSource = obstacle {
        let origin = origins_folder(temporary).join(MISSING_ORIGIN);
        return Ok(repository_at(&origin, AgentAccess::ReadOnly));
    }
    let origin = create_bare_origin(temporary, REPOSITORY_NAME, &[])?;
    Ok(repository_at(&origin, AgentAccess::ReadOnly))
}

fn place_obstacle(
    configuration: &RunnerConfiguration,
    assignment: &RunAssignment,
    obstacle: WorktreeObstacle,
) -> TestResult<String> {
    let task_folder = plan_task_folder(configuration, assignment)?;
    let roots = &configuration.worktree_roots;
    fs::create_dir_all(&roots.worktrees_root)?;
    fs::create_dir_all(&roots.cache_root)?;

    let task_folder_text = task_folder.display().to_string();
    match obstacle {
        WorktreeObstacle::MissingCloneSource => {
            let project = assignment.project.as_ref().ok_or("no project")?;
            let repository =
                project.repositories.first().ok_or("no repository")?;
            Ok(repository.address.clone())
        }
        WorktreeObstacle::FileAtTaskFolder => {
            fs::write(&task_folder, BLOCKING_FILE_CONTENT)?;
            Ok(task_folder_text)
        }
        WorktreeObstacle::LinkToCacheAtTaskFolder => {
            symlink(&roots.cache_root, &task_folder)?;
            Ok(task_folder_text)
        }
        WorktreeObstacle::LinkToCacheAtRepositoryWorktree => {
            let worktree = task_folder.join(REPOSITORY_NAME);
            fs::create_dir_all(&task_folder)?;
            symlink(&roots.cache_root, &worktree)?;
            Ok(worktree.display().to_string())
        }
    }
}

fn execute_attempts(
    configuration: &RunnerConfiguration,
    server: &Arc<FakeServer>,
    assignment: &RunAssignment,
    attempt_count: usize,
) -> TestResult<Vec<RunOutcome>> {
    let executor = AgentRunExecutor::new(
        Arc::clone(server),
        GitBranchPusher,
        configuration,
    )?;
    let runtime = Runtime::new()?;
    let mut outcomes = Vec::new();
    for _attempt in 0..attempt_count {
        let execution = executor.execute(assignment.clone());
        outcomes.push(runtime.block_on(execution));
    }
    Ok(outcomes)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(12))]

    #[test]
    fn test_execute_property_unbuildable_worktree_never_starts_the_agent(
        obstacle in any_obstacle(),
        title in "[A-Za-z ]{0,20}",
        schedule in option::of(Just(JOB_SCHEDULE)),
        run_number in 1_u32..100,
        attempt_count in 1..=MAXIMUM_ATTEMPTS,
    ) {
        let folders = prepare_agent_folders().map_err(to_case_error)?;
        let configuration =
            local_configuration(&folders, 1).map_err(to_case_error)?;
        let task = Task {
            schedule,
            ..claude_task(RUN_NUMBER, &title)
        };
        let repository =
            choose_repository(&folders, obstacle).map_err(to_case_error)?;
        let mut assignment =
            assignment_for(task, None, vec![repository], RUN_NUMBER)
                .map_err(to_case_error)?;
        assignment.run.number = run_number;
        let culprit = place_obstacle(&configuration, &assignment, obstacle)
            .map_err(to_case_error)?;
        let run_id = assignment.run.id;
        let server = Arc::new(FakeServer::with_queue(Vec::new()));

        let outcomes = execute_attempts(
            &configuration,
            &server,
            &assignment,
            attempt_count,
        )
        .map_err(to_case_error)?;

        let events = server.events_of(run_id);
        let expected_outcomes = vec![RunOutcome::Failed; attempt_count];
        let expected_statuses =
            vec![(STEP_NAME.to_string(), StepStatus::Failed); attempt_count];
        let reported_failures = failures(&events);
        prop_assert_eq!(outcomes, expected_outcomes);
        prop_assert_eq!(step_statuses(&events), expected_statuses);
        prop_assert!(branches(&events).is_empty());
        prop_assert_eq!(reported_failures.len(), attempt_count);
        for failure in &reported_failures {
            prop_assert!(failure.reason.starts_with(REASON_START));
            prop_assert!(failure.reason.contains(&culprit));
        }
        let has_records =
            has_agent_records(&folders).map_err(to_case_error)?;
        prop_assert!(!has_records);
    }
}

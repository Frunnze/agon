use std::path::PathBuf;
use std::sync::Arc;

use orchestration_api::work::RunAssignment;
use orchestration_core::identifiers::RunId;
use orchestration_hub::worktree_plan::plan_worktree;
use orchestration_runner::agent_run_executor::AgentRunExecutor;
use orchestration_runner::branch_pusher::GitBranchPusher;
use orchestration_runner::run_executor::{RunExecutor, RunOutcome};
use orchestration_runner::runner_configuration::RunnerConfiguration;
use orchestration_runner::worktree_request::describe_worktree_request;
use tokio::runtime::Runtime;

use crate::fake_agent::{AgentFolders, local_configuration};
use crate::fake_server::FakeServer;
use crate::run_mixes::MixedRun;
use crate::support::TestResult;

type MixExecutor = AgentRunExecutor<FakeServer, GitBranchPusher>;

const ATTEMPTS_WITH_RETRY: usize = 2;
const ATTEMPTS_WITHOUT_RETRY: usize = 1;

#[derive(Debug)]
pub struct AttemptRecord {
    pub run_id: RunId,
    pub attempt_number: usize,
    pub was_folder_present: bool,
    pub task_folder: PathBuf,
    pub outcome: RunOutcome,
}

#[derive(Debug)]
pub struct MixExecution {
    pub server: Arc<FakeServer>,
    pub attempts: Vec<AttemptRecord>,
}

pub fn count_attempts(mixed_run: &MixedRun) -> usize {
    if mixed_run.is_retried {
        return ATTEMPTS_WITH_RETRY;
    }
    ATTEMPTS_WITHOUT_RETRY
}

pub fn execute_mix(
    folders: &AgentFolders,
    mixed_runs: &[MixedRun],
) -> TestResult<MixExecution> {
    let configuration = local_configuration(folders, 1)?;
    let server = Arc::new(FakeServer::with_queue(Vec::new()));
    let executor = AgentRunExecutor::new(
        Arc::clone(&server),
        GitBranchPusher,
        &configuration,
    )?;
    let runtime = Runtime::new()?;

    let mut attempts = Vec::new();
    for mixed_run in mixed_runs {
        for attempt_number in 0..count_attempts(mixed_run) {
            let record = execute_attempt(
                &runtime,
                &executor,
                &configuration,
                &mixed_run.assignment,
                attempt_number,
            )?;
            attempts.push(record);
        }
    }
    Ok(MixExecution { server, attempts })
}

pub fn plan_task_folder(
    configuration: &RunnerConfiguration,
    assignment: &RunAssignment,
) -> TestResult<PathBuf> {
    let request = describe_worktree_request(
        assignment,
        &configuration.worktree_roots,
        &configuration.clone_source,
    );
    Ok(plan_worktree(&request)?.task_folder)
}

fn execute_attempt(
    runtime: &Runtime,
    executor: &MixExecutor,
    configuration: &RunnerConfiguration,
    assignment: &RunAssignment,
    attempt_number: usize,
) -> TestResult<AttemptRecord> {
    let planned_folder = plan_task_folder(configuration, assignment)?;
    let was_folder_present = planned_folder.exists();

    let outcome = runtime.block_on(executor.execute(assignment.clone()));

    Ok(AttemptRecord {
        run_id: assignment.run.id,
        attempt_number,
        was_folder_present,
        task_folder: planned_folder.canonicalize()?,
        outcome,
    })
}

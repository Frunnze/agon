use std::sync::Arc;

use orchestration_api::work::RunAssignment;
use orchestration_core::approval::ApprovalDecision;
use orchestration_core::run::StepStatus;
use orchestration_runner::agent_run_executor::AgentRunExecutor;
use orchestration_runner::branch_pusher::GitBranchPusher;
use orchestration_runner::run_executor::{RunExecutor, RunOutcome};
use orchestration_runner::runner_configuration::RunnerConfiguration;

use crate::fake_server::{ApprovalAnswer, FakeServer};
use crate::support::TestResult;

pub const RUN_NUMBER: u128 = 0x9001;
pub const STEP_NAME: &str = "claude-code";

pub async fn execute_with_git_pusher(
    server: &Arc<FakeServer>,
    configuration: &RunnerConfiguration,
    assignment: RunAssignment,
) -> TestResult<RunOutcome> {
    let executor = AgentRunExecutor::new(
        Arc::clone(server),
        GitBranchPusher,
        configuration,
    )?;
    Ok(executor.execute(assignment).await)
}

pub fn server_answering(decision: ApprovalDecision) -> Arc<FakeServer> {
    let answer = ApprovalAnswer::Decide(decision);
    Arc::new(FakeServer::with_queue(Vec::new()).answering_approvals(answer))
}

pub fn step_status_pairs(
    statuses: &[StepStatus],
) -> Vec<(String, StepStatus)> {
    let mut pairs = Vec::new();
    for status in statuses {
        pairs.push((STEP_NAME.to_string(), *status));
    }
    pairs
}

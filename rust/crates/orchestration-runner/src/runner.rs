use std::sync::Arc;

use crate::agent_run_executor::AgentRunExecutor;
use crate::branch_pusher::GitBranchPusher;
use crate::runner_configuration::RunnerConfiguration;
use crate::runner_loop::{RunnerError, run_runner_loop};
use crate::runner_server::RunnerServer;

pub async fn run_runner<S: RunnerServer>(
    server: Arc<S>,
    configuration: &RunnerConfiguration,
    shutdown: impl Future<Output = ()>,
) -> Result<(), RunnerError> {
    let pusher = GitBranchPusher;
    let executor =
        AgentRunExecutor::new(Arc::clone(&server), pusher, configuration)?;
    let executor = Arc::new(executor);
    run_runner_loop(server, executor, configuration, shutdown).await
}

use std::sync::Arc;
use std::time::Duration;

use orchestration_api::work::{RunAssignment, RunEvent};
use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::clone_source::CloneSource;

use crate::agent_sandbox::AgentSandbox;
use crate::assigned_step::run_assigned_step;
use crate::branch_pusher::BranchPusher;
use crate::run_context::RunContext;
use crate::run_error::RunError;
use crate::run_events::post_run_events;
use crate::run_executor::{RunExecutor, RunOutcome};
use crate::run_reports::report_step_failure;
use crate::run_workspace::prepare_run_workspace;
use crate::runner_configuration::{
    ConfigurationProblem, RunnerConfiguration, WorktreeRoots,
    validate_configuration,
};
use crate::runner_server::RunnerServer;
use crate::step_plan::{StepPlan, plan_assigned_step};

#[derive(Debug)]
pub struct AgentRunExecutor<S, P> {
    server: Arc<S>,
    pusher: Arc<P>,
    sandbox: AgentSandbox,
    worktree_roots: WorktreeRoots,
    clone_source: CloneSource,
    cancellation_check_interval: Duration,
    clone_locks: Arc<CloneLocks>,
}

struct PreparedRun<S, P> {
    step: StepPlan,
    context: RunContext<S, P>,
}

impl<S: RunnerServer, P: BranchPusher> AgentRunExecutor<S, P> {
    pub fn new(
        server: Arc<S>,
        pusher: P,
        configuration: &RunnerConfiguration,
    ) -> Result<Self, ConfigurationProblem> {
        validate_configuration(configuration)?;
        Ok(Self {
            server,
            pusher: Arc::new(pusher),
            sandbox: configuration.sandbox.clone(),
            worktree_roots: configuration.worktree_roots.clone(),
            clone_source: configuration.clone_source.clone(),
            cancellation_check_interval: configuration
                .intervals
                .cancellation_check,
            clone_locks: Arc::new(CloneLocks::default()),
        })
    }

    async fn prepare_run(
        &self,
        assignment: &RunAssignment,
    ) -> Result<PreparedRun<S, P>, RunError> {
        let step = plan_assigned_step(assignment)?;
        let clone_locks = Arc::clone(&self.clone_locks);
        let workspace = prepare_run_workspace(
            assignment,
            &self.worktree_roots,
            &self.clone_source,
            clone_locks,
        )
        .await?;

        let run_id = assignment.run.id;
        let created = RunEvent::WorktreeCreated {
            branch: workspace.branch.clone(),
        };
        post_run_events(self.server.as_ref(), run_id, vec![created]).await?;

        let context = RunContext {
            server: Arc::clone(&self.server),
            pusher: Arc::clone(&self.pusher),
            run_id,
            sandbox: self.sandbox.clone(),
            workspace,
            cancellation_check_interval: self.cancellation_check_interval,
        };
        Ok(PreparedRun { step, context })
    }
}

impl<S: RunnerServer, P: BranchPusher> RunExecutor for AgentRunExecutor<S, P> {
    async fn execute(&self, assignment: RunAssignment) -> RunOutcome {
        match self.prepare_run(&assignment).await {
            Ok(prepared) => {
                let step = &prepared.step;
                run_assigned_step(&prepared.context, &assignment, step).await
            }
            Err(problem) => {
                let reason = problem.to_string();
                let server = self.server.as_ref();
                let run_id = assignment.run.id;
                let step_name = &assignment.step_name;
                report_step_failure(server, run_id, step_name, &reason).await;
                RunOutcome::Failed
            }
        }
    }
}

use std::sync::Arc;
use std::time::Duration;

use orchestration_api::work::{RunAssignment, RunEvent};
use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::clone_source::CloneSource;
use orchestration_hub::workspace_mounts::WorkspaceMounts;

use crate::agent_sandbox::AgentSandbox;
use crate::assigned_step::run_assigned_step;
use crate::branch_pusher::BranchPusher;
use crate::protected_mounts::hide_protected_files;
use crate::run_context::RunContext;
use crate::run_error::RunError;
use crate::run_events::post_run_events;
use crate::run_executor::{RunExecutor, RunOutcome};
use crate::run_reports::report_step_failure;
use crate::run_workspace::{RunWorkspace, prepare_run_workspace};
use crate::runner_configuration::{
    ConfigurationProblem, RunnerConfiguration, WorktreeRoots,
    validate_configuration,
};
use crate::runner_server::RunnerServer;
use crate::sandbox_choice::choose_sandbox;
use crate::step_plan::{StepPlan, plan_assigned_step};
use crate::worktree_departure::leave_worktree;
use crate::worktree_locks::WorktreeLocks;

#[derive(Debug)]
pub struct AgentRunExecutor<S, P> {
    server: Arc<S>,
    pusher: Arc<P>,
    sandboxes: Vec<AgentSandbox>,
    worktree_roots: WorktreeRoots,
    clone_source: CloneSource,
    cancellation_check_interval: Duration,
    clone_locks: Arc<CloneLocks>,
    worktree_locks: WorktreeLocks,
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
            sandboxes: configuration.sandboxes.clone(),
            worktree_roots: configuration.worktree_roots.clone(),
            clone_source: configuration.clone_source.clone(),
            cancellation_check_interval: configuration
                .intervals
                .cancellation_check,
            clone_locks: Arc::new(CloneLocks::default()),
            worktree_locks: WorktreeLocks::default(),
        })
    }

    async fn prepare_run(
        &self,
        assignment: &RunAssignment,
    ) -> Result<PreparedRun<S, P>, RunError> {
        let wanted_place = assignment.task.agent_place;
        let sandbox = choose_sandbox(&self.sandboxes, wanted_place)
            .ok_or(RunError::PlaceNotOffered)?
            .clone();
        let step = plan_assigned_step(assignment)?;
        let clone_locks = Arc::clone(&self.clone_locks);
        let prepared_workspace = prepare_run_workspace(
            assignment,
            &self.worktree_roots,
            &self.clone_source,
            clone_locks,
            &self.worktree_locks,
        )
        .await?;
        let finishing = self
            .finish_workspace_preparation(
                assignment,
                &sandbox,
                &prepared_workspace,
            )
            .await;
        let hidden_mounts = match finishing {
            Ok(hidden_mounts) => hidden_mounts,
            Err(problem) => {
                leave_worktree(&prepared_workspace).await;
                return Err(problem);
            }
        };
        let workspace = RunWorkspace {
            mounts: hidden_mounts,
            ..prepared_workspace
        };

        let context = RunContext {
            server: Arc::clone(&self.server),
            pusher: Arc::clone(&self.pusher),
            run_id: assignment.run.id,
            sandbox,
            workspace,
            protected_files: assignment.protected_files.clone(),
            cancellation_check_interval: self.cancellation_check_interval,
        };
        Ok(PreparedRun { step, context })
    }

    async fn finish_workspace_preparation(
        &self,
        assignment: &RunAssignment,
        sandbox: &AgentSandbox,
        workspace: &RunWorkspace,
    ) -> Result<WorkspaceMounts, RunError> {
        let hidden_mounts = hide_protected_files(
            sandbox.kind,
            &workspace.mounts,
            &assignment.protected_files,
        )
        .await?;

        let created = RunEvent::WorktreeCreated {
            branch: workspace.branch.clone(),
        };
        let run_id = assignment.run.id;
        post_run_events(self.server.as_ref(), run_id, vec![created]).await?;
        Ok(hidden_mounts)
    }
}

impl<S: RunnerServer, P: BranchPusher> RunExecutor for AgentRunExecutor<S, P> {
    async fn execute(&self, assignment: RunAssignment) -> RunOutcome {
        match self.prepare_run(&assignment).await {
            Ok(prepared) => {
                let step = &prepared.step;
                let context = &prepared.context;
                run_assigned_step(context, &assignment, step).await
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

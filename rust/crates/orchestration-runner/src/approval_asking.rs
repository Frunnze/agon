use orchestration_api::work::CreateApprovalRequest;
use orchestration_core::approval::{ApprovalAction, ApprovalDecision};
use orchestration_core::run::StepStatus;

use crate::branch_pusher::BranchPusher;
use crate::cancellation_watch::wait_until_cancelled;
use crate::run_context::RunContext;
use crate::run_error::RunError;
use crate::run_events::{post_run_events, step_status_changed};
use crate::runner_server::RunnerServer;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum ApprovalOutcome {
    Decided(ApprovalDecision),
    Cancelled,
}

pub(crate) async fn ask_for_approval<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step_name: &str,
    action: ApprovalAction,
) -> Result<ApprovalOutcome, RunError> {
    let server = context.server.as_ref();
    let waiting =
        step_status_changed(step_name, StepStatus::WaitingForApproval);
    post_run_events(server, context.run_id, vec![waiting]).await?;

    let request = CreateApprovalRequest {
        run_id: Some(context.run_id),
        action,
    };
    let cancellation = wait_until_cancelled(
        server,
        context.run_id,
        context.cancellation_check_interval,
    );
    tokio::select! {
        decision = server.request_approval_decision(&request) => {
            Ok(ApprovalOutcome::Decided(decision?))
        }
        () = cancellation => Ok(ApprovalOutcome::Cancelled),
    }
}

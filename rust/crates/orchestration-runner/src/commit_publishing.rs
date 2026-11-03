use chrono::Utc;
use orchestration_core::approval::{ApprovalAction, ApprovalDecision};
use orchestration_core::run::ChatAuthor;

use crate::approval_asking::{ApprovalOutcome, ask_for_approval};
use crate::branch_pusher::BranchPusher;
use crate::push_decision::{PushDecision, decide_push};
use crate::run_context::RunContext;
use crate::run_error::RunError;
use crate::run_events::{chat_appended, post_run_events};
use crate::run_workspace::RepositoryCheckout;
use crate::runner_server::RunnerServer;
use crate::step_plan::StepPlan;
use crate::unpushed_commits::list_unpushed_commit_subjects;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Publishing {
    Completed,
    Cancelled,
}

pub(crate) async fn publish_commits<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
) -> Result<Publishing, RunError> {
    let branch = &context.workspace.branch;
    for checkout in &context.workspace.checkouts {
        let commits =
            list_unpushed_commit_subjects(&checkout.worktree).await?;
        let decision = decide_push(
            step.approval_policy,
            &checkout.repository,
            branch,
            &commits,
        );
        let publishing =
            carry_out_push(context, step, checkout, decision).await?;
        if publishing == Publishing::Cancelled {
            return Ok(Publishing::Cancelled);
        }
    }
    Ok(Publishing::Completed)
}

async fn carry_out_push<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    checkout: &RepositoryCheckout,
    decision: PushDecision,
) -> Result<Publishing, RunError> {
    match decision {
        PushDecision::KeepLocal => Ok(Publishing::Completed),
        PushDecision::PushNow => {
            push_checkout(context, checkout).await?;
            Ok(Publishing::Completed)
        }
        PushDecision::AskFirst(action) => {
            ask_then_push(context, step, checkout, action).await
        }
    }
}

async fn ask_then_push<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    checkout: &RepositoryCheckout,
    action: ApprovalAction,
) -> Result<Publishing, RunError> {
    let outcome = ask_for_approval(context, &step.name, action).await?;
    let ApprovalOutcome::Decided(decision) = outcome else {
        return Ok(Publishing::Cancelled);
    };

    match decision {
        ApprovalDecision::Approved => push_checkout(context, checkout).await?,
        ApprovalDecision::Denied => {
            report_denied_push(context, checkout).await?;
        }
    }
    Ok(Publishing::Completed)
}

async fn push_checkout<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    checkout: &RepositoryCheckout,
) -> Result<(), RunError> {
    let branch = &context.workspace.branch;
    context
        .pusher
        .push_branch(&checkout.worktree, branch)
        .await?;
    Ok(())
}

async fn report_denied_push<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    checkout: &RepositoryCheckout,
) -> Result<(), RunError> {
    let note = format!(
        "The push to {} in {} was denied, so nothing was pushed.",
        context.workspace.branch, checkout.repository.address
    );
    let event = chat_appended(ChatAuthor::Tool, &note, Utc::now());
    let server = context.server.as_ref();
    post_run_events(server, context.run_id, vec![event]).await?;
    Ok(())
}

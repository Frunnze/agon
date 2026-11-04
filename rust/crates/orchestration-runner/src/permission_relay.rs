use chrono::Utc;
use orchestration_core::run::StepStatus;
use orchestration_hub::claude_control::{
    ClaudeControlLine, ToolPermissionRequest, read_control_line,
    write_permission_answer,
};
use orchestration_hub::requested_action::describe_requested_action;
use orchestration_hub::workspace_mounts::locate_task_folder_seen_by_agent;
use tokio::sync::mpsc::{UnboundedReceiver, UnboundedSender};

use crate::approval_asking::{ApprovalOutcome, ask_for_approval};
use crate::branch_pusher::BranchPusher;
use crate::cancellation_watch::wait_until_cancelled;
use crate::live_input::LiveInput;
use crate::output_relay::{RelayEnding, RelayedOutput, relay_line};
use crate::run_context::RunContext;
use crate::run_error::RunError;
use crate::run_events::{
    message_delivered, post_run_events, step_status_changed,
};
use crate::runner_server::RunnerServer;
use crate::step_plan::StepPlan;
use crate::user_message_watch::wait_for_new_user_messages;

pub(crate) async fn relay_answering_permissions<
    S: RunnerServer,
    P: BranchPusher,
>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    relayed: RelayedOutput,
    output_lines: &mut UnboundedReceiver<String>,
    input_lines: UnboundedSender<String>,
    prompt_line: String,
) -> Result<RelayEnding, RunError> {
    let mut live_input = LiveInput::open(input_lines, prompt_line)?;

    let server = context.server.as_ref();
    let run_id = context.run_id;
    let check_interval = context.cancellation_check_interval;
    let cancellation = wait_until_cancelled(server, run_id, check_interval);
    tokio::pin!(cancellation);
    let answered_messages = relayed.transcript.answered_messages;
    let new_user_messages = wait_for_new_user_messages(
        server,
        run_id,
        answered_messages,
        check_interval,
    );
    tokio::pin!(new_user_messages);
    let mut relayed = relayed;

    loop {
        let is_interruptible = live_input.is_interruptible();
        let next_line = tokio::select! {
            biased;
            () = &mut cancellation => return Ok(RelayEnding::Cancelled),
            new_messages = &mut new_user_messages, if is_interruptible => {
                let answered_messages = new_messages.answered_messages;
                live_input.interrupt(new_messages)?;
                new_user_messages.set(wait_for_new_user_messages(
                    server,
                    run_id,
                    answered_messages,
                    check_interval,
                ));
                continue;
            }
            next_line = output_lines.recv() => next_line,
        };
        let Some(line) = next_line else {
            return Ok(RelayEnding::OutputEnded(relayed.transcript));
        };

        match read_control_line(&line) {
            ClaudeControlLine::PermissionRequest(request) => {
                let outcome =
                    answer_permission(context, step, &request, &live_input)
                        .await?;
                if outcome == ApprovalOutcome::Cancelled {
                    return Ok(RelayEnding::Cancelled);
                }
                continue;
            }
            ClaudeControlLine::RequestAnswered(request_id) => {
                let delivered = live_input.deliver_answered(&request_id)?;
                if let Some(new_messages) = delivered {
                    let note = message_delivered(Utc::now());
                    post_run_events(server, run_id, vec![note]).await?;
                    let answered_messages = new_messages.answered_messages;
                    relayed = relayed.having_answered(answered_messages);
                }
                continue;
            }
            ClaudeControlLine::TurnEnded => live_input.end_turn(),
            ClaudeControlLine::Other => {}
        }
        relayed =
            relay_line(server, run_id, &step.name, relayed, &line).await?;
    }
}

async fn answer_permission<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    request: &ToolPermissionRequest,
    live_input: &LiveInput,
) -> Result<ApprovalOutcome, RunError> {
    let task_folder = locate_task_folder_seen_by_agent(
        context.sandbox.kind,
        &context.workspace.mounts,
    );
    let action =
        describe_requested_action(request, &task_folder.to_string_lossy());
    let outcome = ask_for_approval(context, &step.name, action).await?;
    let ApprovalOutcome::Decided(decision) = outcome else {
        return Ok(outcome);
    };

    let running = step_status_changed(&step.name, StepStatus::Running);
    let server = context.server.as_ref();
    post_run_events(server, context.run_id, vec![running]).await?;
    let answer = write_permission_answer(request, decision);
    live_input.send(answer)?;
    Ok(outcome)
}

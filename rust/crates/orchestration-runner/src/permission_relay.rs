use orchestration_core::run::StepStatus;
use orchestration_hub::agent_output::AgentOutputReader;
use orchestration_hub::claude_control::{
    ClaudeControlLine, ToolPermissionRequest, read_control_line,
    write_permission_answer,
};
use orchestration_hub::requested_action::describe_requested_action;
use tokio::sync::mpsc::{UnboundedReceiver, UnboundedSender};

use crate::approval_asking::{ApprovalOutcome, ask_for_approval};
use crate::branch_pusher::BranchPusher;
use crate::cancellation_watch::wait_until_cancelled;
use crate::output_relay::{RelayEnding, RelayedOutput, relay_line};
use crate::run_context::RunContext;
use crate::run_error::RunError;
use crate::run_events::{post_run_events, step_status_changed};
use crate::runner_server::RunnerServer;
use crate::step_plan::StepPlan;

pub(crate) async fn relay_answering_permissions<
    S: RunnerServer,
    P: BranchPusher,
>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    output_reader: AgentOutputReader,
    output_lines: &mut UnboundedReceiver<String>,
    input_lines: UnboundedSender<String>,
    prompt_line: String,
) -> Result<RelayEnding, RunError> {
    let mut open_input = Some(input_lines);
    send_to_agent(open_input.as_ref(), prompt_line)?;

    let server = context.server.as_ref();
    let cancellation = wait_until_cancelled(
        server,
        context.run_id,
        context.cancellation_check_interval,
    );
    tokio::pin!(cancellation);
    let mut relayed = RelayedOutput::new(output_reader);

    loop {
        let next_line = tokio::select! {
            biased;
            () = &mut cancellation => return Ok(RelayEnding::Cancelled),
            next_line = output_lines.recv() => next_line,
        };
        let Some(line) = next_line else {
            return Ok(RelayEnding::OutputEnded(relayed.transcript));
        };

        let control_line = read_control_line(&line);
        if let ClaudeControlLine::PermissionRequest(request) = control_line {
            let agent_input = open_input.as_ref();
            let outcome =
                answer_permission(context, step, &request, agent_input)
                    .await?;
            if outcome == ApprovalOutcome::Cancelled {
                return Ok(RelayEnding::Cancelled);
            }
            continue;
        }

        if control_line == ClaudeControlLine::TurnEnded {
            open_input = None;
        }
        let run_id = context.run_id;
        relayed =
            relay_line(server, run_id, &step.name, relayed, &line).await?;
    }
}

async fn answer_permission<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    request: &ToolPermissionRequest,
    agent_input: Option<&UnboundedSender<String>>,
) -> Result<ApprovalOutcome, RunError> {
    let action = describe_requested_action(request);
    let outcome = ask_for_approval(context, &step.name, action).await?;
    let ApprovalOutcome::Decided(decision) = outcome else {
        return Ok(outcome);
    };

    let running = step_status_changed(&step.name, StepStatus::Running);
    let server = context.server.as_ref();
    post_run_events(server, context.run_id, vec![running]).await?;
    let answer = write_permission_answer(request, decision);
    send_to_agent(agent_input, answer)?;
    Ok(outcome)
}

fn send_to_agent(
    agent_input: Option<&UnboundedSender<String>>,
    line: String,
) -> Result<(), RunError> {
    let Some(agent_input) = agent_input else {
        return Err(RunError::AgentInputClosed);
    };
    agent_input
        .send(line)
        .map_err(|_unsent_line| RunError::AgentInputClosed)
}

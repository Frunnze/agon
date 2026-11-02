use orchestration_hub::process_supervisor::{
    ProcessExit, RunningProcess, start_process,
};
use tokio::task::spawn_blocking;

use crate::agent_transcript::AgentTranscript;
use crate::branch_pusher::BranchPusher;
use crate::cancellation_watch::wait_until_cancelled;
use crate::output_relay::{RelayEnding, relay_agent_output};
use crate::run_context::RunContext;
use crate::run_error::RunError;
use crate::runner_server::RunnerServer;
use crate::step_command::build_step_command;
use crate::step_plan::StepPlan;

pub(crate) enum AgentEnding {
    Succeeded(AgentTranscript),
    Failed(String),
    Cancelled,
}

pub(crate) async fn invoke_agent<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    prompt: &str,
    session: Option<&str>,
) -> Result<AgentEnding, RunError> {
    let command = build_step_command(
        &context.sandbox,
        &context.workspace.mounts,
        step.agent,
        prompt,
        session,
    )?;
    let mut process = start_process(&command)?;

    let server = context.server.as_ref();
    let cancellation = wait_until_cancelled(
        server,
        context.run_id,
        context.cancellation_check_interval,
    );
    let relayed = relay_agent_output(
        server,
        context.run_id,
        &step.name,
        step.agent,
        &mut process.output_lines,
        cancellation,
    )
    .await;

    match relayed {
        Ok(RelayEnding::OutputEnded(transcript)) => {
            let exit = wait_for_exit_in_background(process).await?;
            Ok(describe_agent_ending(exit, transcript))
        }
        Ok(RelayEnding::Cancelled) => {
            stop_and_reap(process).await?;
            Ok(AgentEnding::Cancelled)
        }
        Err(problem) => {
            stop_and_reap(process).await?;
            Err(problem.into())
        }
    }
}

fn describe_agent_ending(
    exit: ProcessExit,
    transcript: AgentTranscript,
) -> AgentEnding {
    match exit {
        ProcessExit::Succeeded => AgentEnding::Succeeded(transcript),
        ProcessExit::FailedWithCode(code) => {
            let fallback = format!("the agent exited with code {code}");
            fail_with_reason(transcript, fallback)
        }
        ProcessExit::KilledBySignal(signal) => {
            let fallback = format!("the agent was stopped by signal {signal}");
            fail_with_reason(transcript, fallback)
        }
    }
}

fn fail_with_reason(
    transcript: AgentTranscript,
    fallback_reason: String,
) -> AgentEnding {
    let reason = transcript.failure_reason.unwrap_or(fallback_reason);
    AgentEnding::Failed(reason)
}

async fn wait_for_exit_in_background(
    mut process: RunningProcess,
) -> Result<ProcessExit, RunError> {
    let waiting = spawn_blocking(move || process.wait_for_exit());
    Ok(waiting.await??)
}

async fn stop_and_reap(mut process: RunningProcess) -> Result<(), RunError> {
    process.stop()?;
    let _stopped_exit = wait_for_exit_in_background(process).await?;
    Ok(())
}

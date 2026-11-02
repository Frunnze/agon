use chrono::Utc;
use orchestration_core::identifiers::RunId;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_output::parse_agent_line;
use tokio::sync::mpsc::UnboundedReceiver;

use crate::agent_transcript::AgentTranscript;
use crate::line_events::describe_line_events;
use crate::run_events::post_run_events;
use crate::runner_server::{RunnerServer, ServerError};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RelayEnding {
    OutputEnded(AgentTranscript),
    Cancelled,
}

pub async fn relay_agent_output<S: RunnerServer>(
    server: &S,
    run_id: RunId,
    step_name: &str,
    agent: AgentKind,
    output_lines: &mut UnboundedReceiver<String>,
    cancellation: impl Future<Output = ()>,
) -> Result<RelayEnding, ServerError> {
    tokio::pin!(cancellation);
    let mut transcript = AgentTranscript::default();

    loop {
        let next_line = tokio::select! {
            biased;
            () = &mut cancellation => return Ok(RelayEnding::Cancelled),
            next_line = output_lines.recv() => next_line,
        };
        let Some(line) = next_line else {
            return Ok(RelayEnding::OutputEnded(transcript));
        };

        let agent_events = parse_agent_line(agent, &line);
        let run_events =
            describe_line_events(step_name, &line, &agent_events, Utc::now());
        post_run_events(server, run_id, run_events).await?;
        transcript = transcript.record(&agent_events);
    }
}

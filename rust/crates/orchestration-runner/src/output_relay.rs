use chrono::Utc;
use orchestration_core::identifiers::RunId;
use orchestration_hub::agent_output::AgentOutputReader;
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

pub(crate) struct RelayedOutput {
    reader: AgentOutputReader,
    pub(crate) transcript: AgentTranscript,
}

impl RelayedOutput {
    pub(crate) fn new(reader: AgentOutputReader) -> Self {
        Self {
            reader,
            transcript: AgentTranscript::default(),
        }
    }
}

pub async fn relay_agent_output<S: RunnerServer>(
    server: &S,
    run_id: RunId,
    step_name: &str,
    output_reader: AgentOutputReader,
    output_lines: &mut UnboundedReceiver<String>,
    cancellation: impl Future<Output = ()>,
) -> Result<RelayEnding, ServerError> {
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

        relayed =
            relay_line(server, run_id, step_name, relayed, &line).await?;
    }
}

pub(crate) async fn relay_line<S: RunnerServer>(
    server: &S,
    run_id: RunId,
    step_name: &str,
    relayed: RelayedOutput,
    line: &str,
) -> Result<RelayedOutput, ServerError> {
    let (reader, agent_events) = relayed.reader.read_line(line);
    let run_events =
        describe_line_events(step_name, line, &agent_events, Utc::now());
    post_run_events(server, run_id, run_events).await?;
    let transcript = relayed.transcript.record(&agent_events);
    Ok(RelayedOutput { reader, transcript })
}

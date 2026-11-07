use chrono::Utc;
use orchestration_core::identifiers::RunId;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_log::{
    describe_agent_event_log_lines, describe_agent_log_lines,
};
use orchestration_hub::agent_output::AgentOutputReader;
use tokio::sync::mpsc::UnboundedReceiver;

use crate::agent_transcript::AgentTranscript;
use crate::line_events::describe_relayed_events;
use crate::run_events::{message_delivered, post_run_events};
use crate::runner_server::{RunnerServer, ServerError};
use crate::user_message_watch::NewUserMessages;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RelayEnding {
    OutputEnded(AgentTranscript),
    Cancelled,
    NewUserMessages(AgentTranscript),
}

#[derive(Debug)]
pub struct RelayedOutput {
    reader: AgentOutputReader,
    pub(crate) transcript: AgentTranscript,
    has_ended_turn: bool,
}

impl RelayedOutput {
    #[must_use]
    pub fn new(reader: AgentOutputReader, answered_messages: usize) -> Self {
        Self {
            reader,
            transcript: AgentTranscript {
                answered_messages,
                ..AgentTranscript::default()
            },
            has_ended_turn: false,
        }
    }

    pub(crate) fn having_answered(self, answered_messages: usize) -> Self {
        let transcript = AgentTranscript {
            answered_messages,
            ..self.transcript
        };
        Self { transcript, ..self }
    }

    fn can_stop_for_new_messages(&self) -> bool {
        self.transcript.session.is_some() && !self.has_ended_turn
    }
}

pub async fn relay_agent_output<S: RunnerServer>(
    server: &S,
    run_id: RunId,
    step_name: &str,
    relayed: RelayedOutput,
    output_lines: &mut UnboundedReceiver<String>,
    cancellation: impl Future<Output = ()>,
    new_user_messages: impl Future<Output = NewUserMessages>,
) -> Result<RelayEnding, ServerError> {
    tokio::pin!(cancellation);
    tokio::pin!(new_user_messages);
    let mut relayed = relayed;

    loop {
        let can_stop_for_new_messages = relayed.can_stop_for_new_messages();
        let next_line = tokio::select! {
            biased;
            () = &mut cancellation => return Ok(RelayEnding::Cancelled),
            _ = &mut new_user_messages, if can_stop_for_new_messages => {
                let transcript =
                    relay_end_of_output(server, run_id, step_name, relayed)
                        .await?;
                let delivered = message_delivered(Utc::now());
                post_run_events(server, run_id, vec![delivered]).await?;
                return Ok(RelayEnding::NewUserMessages(transcript));
            }
            next_line = output_lines.recv() => next_line,
        };
        let Some(line) = next_line else {
            let transcript =
                relay_end_of_output(server, run_id, step_name, relayed)
                    .await?;
            return Ok(RelayEnding::OutputEnded(transcript));
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
    let agent_log_lines = describe_agent_log_lines(line, &agent_events);
    let run_events = describe_relayed_events(
        step_name,
        agent_log_lines,
        &agent_events,
        Utc::now(),
    );
    post_run_events(server, run_id, run_events).await?;

    let transcript = relayed.transcript.record(&agent_events);
    let has_ended_turn =
        relayed.has_ended_turn || reports_turn_end(&agent_events);
    Ok(RelayedOutput {
        reader,
        transcript,
        has_ended_turn,
    })
}

async fn relay_end_of_output<S: RunnerServer>(
    server: &S,
    run_id: RunId,
    step_name: &str,
    relayed: RelayedOutput,
) -> Result<AgentTranscript, ServerError> {
    let agent_events = relayed.reader.read_end_of_output();
    if agent_events.is_empty() {
        return Ok(relayed.transcript);
    }

    let agent_log_lines = describe_agent_event_log_lines(&agent_events);
    let run_events = describe_relayed_events(
        step_name,
        agent_log_lines,
        &agent_events,
        Utc::now(),
    );
    post_run_events(server, run_id, run_events).await?;
    Ok(relayed.transcript.record(&agent_events))
}

fn reports_turn_end(agent_events: &[AgentEvent]) -> bool {
    agent_events.iter().any(|agent_event| {
        matches!(agent_event, AgentEvent::Finished | AgentEvent::Failed(_))
    })
}

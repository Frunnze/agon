use chrono::{DateTime, Utc};
use orchestration_api::work::RunEvent;
use orchestration_core::run::{ChatAuthor, LogLine};
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_log::describe_agent_log_lines;

use crate::run_events::chat_appended;

pub(crate) fn describe_line_events(
    step_name: &str,
    line: &str,
    agent_events: &[AgentEvent],
    at: DateTime<Utc>,
) -> Vec<RunEvent> {
    let mut run_events = Vec::new();
    for agent_log_line in describe_agent_log_lines(line, agent_events) {
        let log_line = LogLine {
            at,
            step_name: step_name.to_string(),
            text: agent_log_line.text,
            is_error: agent_log_line.is_error,
        };
        run_events.push(RunEvent::LogAppended { line: log_line });
    }

    for agent_event in agent_events {
        match agent_event {
            AgentEvent::Said(text) => {
                run_events.push(chat_appended(ChatAuthor::Agent, text, at));
            }
            AgentEvent::UsedTool(description) => {
                let event = chat_appended(ChatAuthor::Tool, description, at);
                run_events.push(event);
            }
            AgentEvent::SessionStarted(session) => {
                run_events.push(RunEvent::SessionStarted {
                    session: session.clone(),
                });
            }
            AgentEvent::ToolFailed(_)
            | AgentEvent::Finished
            | AgentEvent::Failed(_)
            | AgentEvent::AskedForApproval(_) => {}
        }
    }
    run_events
}

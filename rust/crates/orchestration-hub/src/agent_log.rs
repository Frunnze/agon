use crate::agent_event::AgentEvent;
use crate::json_lines::reads_as_json;
use crate::terminal_text::strip_terminal_control_sequences;
use crate::text_shortening::shorten_to_characters;

const MAXIMUM_LOG_TEXT_CHARACTERS: usize = 120;
const SAID_PREFIX: &str = "Said: ";
const FAILED_PREFIX: &str = "Failed: ";
const SESSION_PREFIX: &str = "Agent started, session ";
const FINISHED_TEXT: &str = "Finished";
const WORD_SEPARATOR: &str = " ";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AgentLogLine {
    pub text: String,
    pub is_error: bool,
}

#[must_use]
pub fn describe_agent_log_lines(
    line: &str,
    agent_events: &[AgentEvent],
) -> Vec<AgentLogLine> {
    let visible_text = strip_terminal_control_sequences(line);
    let printed_text = visible_text.trim_end();
    if printed_text.trim_start().is_empty() {
        return Vec::new();
    }
    if !reads_as_json(&join_words(printed_text)) {
        return vec![normal_line(printed_text.to_string())];
    }

    let mut log_lines = Vec::new();
    for agent_event in agent_events {
        if let Some(log_line) = describe_agent_event(agent_event) {
            log_lines.push(log_line);
        }
    }
    log_lines
}

fn describe_agent_event(agent_event: &AgentEvent) -> Option<AgentLogLine> {
    match agent_event {
        AgentEvent::Said(text) => {
            let said = shorten_readable_text(text)?;
            Some(normal_line(format!("{SAID_PREFIX}{said}")))
        }
        AgentEvent::UsedTool(description) => {
            Some(normal_line(description.clone()))
        }
        AgentEvent::ToolFailed(error) => {
            shorten_readable_text(error).map(error_line)
        }
        AgentEvent::Finished => Some(normal_line(FINISHED_TEXT.to_string())),
        AgentEvent::Failed(reason) => {
            let reason = shorten_readable_text(reason)?;
            Some(error_line(format!("{FAILED_PREFIX}{reason}")))
        }
        AgentEvent::SessionStarted(session) => {
            let session = shorten_readable_text(session)?;
            Some(normal_line(format!("{SESSION_PREFIX}{session}")))
        }
        AgentEvent::AskedForApproval(_) => None,
    }
}

fn shorten_readable_text(text: &str) -> Option<String> {
    let one_line = join_words(text);
    if reads_as_json(&one_line) {
        return None;
    }
    Some(shorten_to_characters(
        &one_line,
        MAXIMUM_LOG_TEXT_CHARACTERS,
    ))
}

fn join_words(text: &str) -> String {
    let words: Vec<&str> = text.split_whitespace().collect();
    words.join(WORD_SEPARATOR)
}

fn normal_line(text: String) -> AgentLogLine {
    AgentLogLine {
        text,
        is_error: false,
    }
}

fn error_line(text: String) -> AgentLogLine {
    AgentLogLine {
        text,
        is_error: true,
    }
}

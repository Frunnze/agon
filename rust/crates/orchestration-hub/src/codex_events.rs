use serde::Deserialize;

use crate::agent_event::AgentEvent;
use crate::codex_items::{
    CodexError, CodexItem, describe_completed_item, describe_started_item,
};
use crate::failure_texts::{
    UNKNOWN_AGENT_ERROR, UNKNOWN_FAILURE_REASON, choose_given_text,
};
use crate::json_lines::describe_unread_line;

#[derive(Debug, Deserialize)]
#[serde(tag = "type")]
enum CodexEvent {
    #[serde(rename = "thread.started")]
    ThreadStarted { thread_id: String },
    #[serde(rename = "item.started")]
    ItemStarted { item: CodexItem },
    #[serde(rename = "item.completed")]
    ItemCompleted { item: CodexItem },
    #[serde(rename = "turn.completed")]
    TurnCompleted,
    #[serde(rename = "turn.failed")]
    TurnFailed {
        #[serde(default)]
        error: CodexError,
    },
    #[serde(rename = "error")]
    Error {
        #[serde(default)]
        message: String,
    },
    #[serde(other)]
    Other,
}

pub(crate) fn parse_codex_line(
    line: &str,
    task_folder: &str,
) -> Vec<AgentEvent> {
    let Ok(event) = serde_json::from_str::<CodexEvent>(line) else {
        return describe_unread_line(line);
    };

    match event {
        CodexEvent::ThreadStarted { thread_id } => start_session(thread_id),
        CodexEvent::ItemStarted { item } => {
            describe_started_item(&item, task_folder)
        }
        CodexEvent::ItemCompleted { item } => {
            describe_completed_item(&item, task_folder)
        }
        CodexEvent::TurnCompleted => vec![AgentEvent::Finished],
        CodexEvent::TurnFailed { error } => {
            let given_reason = [error.message.as_str()];
            let reason =
                choose_given_text(&given_reason, UNKNOWN_FAILURE_REASON);
            vec![AgentEvent::Failed(reason)]
        }
        CodexEvent::Error { message } => {
            let error = choose_given_text(&[&message], UNKNOWN_AGENT_ERROR);
            vec![AgentEvent::ToolFailed(error)]
        }
        CodexEvent::Other => Vec::new(),
    }
}

fn start_session(thread_id: String) -> Vec<AgentEvent> {
    if thread_id.trim().is_empty() {
        return Vec::new();
    }
    vec![AgentEvent::SessionStarted(thread_id)]
}

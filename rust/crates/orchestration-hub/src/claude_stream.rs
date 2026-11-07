use serde::Deserialize;
use serde_json::Value;

use crate::agent_event::AgentEvent;
use crate::claude_tool_results::describe_tool_failures;
use crate::failure_texts::{UNKNOWN_FAILURE_REASON, choose_given_text};
use crate::json_lines::describe_unread_line;
use crate::known_tools::CLAUDE_TOOLS;
use crate::tool_description::describe_tool_use;

const INITIALIZED_SUBTYPE: &str = "init";
const SUCCESS_SUBTYPE: &str = "success";

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ClaudeStreamEvent {
    System {
        subtype: Option<String>,
        session_id: Option<String>,
    },
    Assistant {
        message: ClaudeMessage,
    },
    User {
        #[serde(default)]
        message: Value,
    },
    Result {
        subtype: Option<String>,
        is_error: Option<bool>,
        result: Option<String>,
    },
    #[serde(other)]
    Other,
}

#[derive(Debug, Deserialize)]
struct ClaudeMessage {
    content: Vec<ClaudeContent>,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ClaudeContent {
    Text {
        text: String,
    },
    ToolUse {
        name: String,
        #[serde(default)]
        input: Value,
    },
    #[serde(other)]
    Other,
}

pub(crate) fn parse_claude_line(
    line: &str,
    task_folder: &str,
) -> Vec<AgentEvent> {
    let Ok(event) = serde_json::from_str::<ClaudeStreamEvent>(line) else {
        return describe_unread_line(line);
    };

    match event {
        ClaudeStreamEvent::System {
            subtype,
            session_id,
        } => describe_system_event(subtype.as_deref(), session_id),
        ClaudeStreamEvent::Assistant { message } => {
            describe_message(&message, task_folder)
        }
        ClaudeStreamEvent::User { message } => {
            describe_tool_failures(&message)
        }
        ClaudeStreamEvent::Result {
            subtype,
            is_error,
            result,
        } => vec![describe_result(subtype.as_deref(), is_error, result)],
        ClaudeStreamEvent::Other => Vec::new(),
    }
}

fn describe_system_event(
    subtype: Option<&str>,
    session_id: Option<String>,
) -> Vec<AgentEvent> {
    let session = session_id.filter(|session| !session.trim().is_empty());
    match (subtype, session) {
        (Some(INITIALIZED_SUBTYPE), Some(session)) => {
            vec![AgentEvent::SessionStarted(session)]
        }
        _ => Vec::new(),
    }
}

fn describe_message(
    message: &ClaudeMessage,
    task_folder: &str,
) -> Vec<AgentEvent> {
    let mut events = Vec::new();
    for content in &message.content {
        match content {
            ClaudeContent::Text { text } if !text.trim().is_empty() => {
                events.push(AgentEvent::Said(text.trim().to_string()));
            }
            ClaudeContent::ToolUse { name, input } => {
                let description =
                    describe_tool_use(&CLAUDE_TOOLS, name, input, task_folder);
                events.push(AgentEvent::UsedTool(description));
            }
            ClaudeContent::Text { .. } | ClaudeContent::Other => {}
        }
    }
    events
}

fn describe_result(
    subtype: Option<&str>,
    is_error: Option<bool>,
    result: Option<String>,
) -> AgentEvent {
    let has_succeeded =
        subtype == Some(SUCCESS_SUBTYPE) && is_error != Some(true);
    if has_succeeded {
        return AgentEvent::Finished;
    }

    let given_reason = result.unwrap_or_default();
    let error_subtype = subtype
        .filter(|name| name.trim() != SUCCESS_SUBTYPE)
        .unwrap_or_default();
    let given_reasons = [given_reason.as_str(), error_subtype];
    let reason = choose_given_text(&given_reasons, UNKNOWN_FAILURE_REASON);
    AgentEvent::Failed(reason)
}

use serde::Deserialize;
use serde_json::Value;

use crate::agent_event::AgentEvent;
use crate::claude_tool_results::describe_tool_failures;
use crate::tool_description::describe_tool_use;

const INITIALIZED_SUBTYPE: &str = "init";
const SUCCESS_SUBTYPE: &str = "success";
const UNKNOWN_FAILURE_REASON: &str = "the agent stopped with an error";

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

pub(crate) fn parse_claude_line(line: &str) -> Vec<AgentEvent> {
    let Ok(event) = serde_json::from_str::<ClaudeStreamEvent>(line) else {
        return vec![AgentEvent::Said(line.to_string())];
    };

    match event {
        ClaudeStreamEvent::System {
            subtype,
            session_id,
        } => describe_system_event(subtype.as_deref(), session_id),
        ClaudeStreamEvent::Assistant { message } => describe_message(&message),
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

fn describe_message(message: &ClaudeMessage) -> Vec<AgentEvent> {
    let mut events = Vec::new();
    for content in &message.content {
        match content {
            ClaudeContent::Text { text } if !text.trim().is_empty() => {
                events.push(AgentEvent::Said(text.trim().to_string()));
            }
            ClaudeContent::ToolUse { name, input } => {
                events.push(AgentEvent::UsedTool(describe_tool_use(
                    name, input,
                )));
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

    let given_reason = result
        .map(|text| text.trim().to_string())
        .filter(|text| !text.is_empty());
    let subtype_reason = subtype
        .filter(|name| !name.trim().is_empty() && *name != SUCCESS_SUBTYPE)
        .map(ToString::to_string);
    let reason = given_reason
        .or(subtype_reason)
        .unwrap_or_else(|| UNKNOWN_FAILURE_REASON.to_string());
    AgentEvent::Failed(reason)
}

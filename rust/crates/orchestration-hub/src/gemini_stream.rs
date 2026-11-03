use serde::Deserialize;
use serde_json::Value;

use crate::agent_event::AgentEvent;
use crate::failure_texts::{
    UNKNOWN_AGENT_ERROR, UNKNOWN_FAILURE_REASON, UNKNOWN_TOOL_FAILURE,
    choose_given_text,
};
use crate::json_lines::describe_unread_line;
use crate::known_tools::GEMINI_TOOLS;
use crate::tool_description::describe_tool_use;

const ASSISTANT_ROLE: &str = "assistant";
const SUCCESS_STATUS: &str = "success";
const ERROR_STATUS: &str = "error";

pub(crate) enum GeminiLine {
    SpeechPart(String),
    EndsSpeech(Vec<AgentEvent>),
    KeepsSpeech(Vec<AgentEvent>),
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum GeminiEvent {
    Init {
        #[serde(default)]
        session_id: String,
    },
    Message {
        #[serde(default)]
        role: String,
        #[serde(default)]
        content: String,
    },
    ToolUse {
        #[serde(default)]
        tool_name: String,
        #[serde(default)]
        parameters: Value,
    },
    ToolResult {
        #[serde(default)]
        status: String,
        #[serde(default)]
        output: String,
        #[serde(default)]
        error: GeminiError,
    },
    Error {
        #[serde(default)]
        message: String,
    },
    Result {
        #[serde(default)]
        status: String,
        #[serde(default)]
        error: GeminiError,
    },
    #[serde(other)]
    Other,
}

#[derive(Debug, Default, Deserialize)]
struct GeminiError {
    #[serde(default)]
    message: String,
    #[serde(default, rename = "type")]
    error_type: String,
}

pub(crate) fn parse_gemini_line(line: &str, task_folder: &str) -> GeminiLine {
    let Ok(event) = serde_json::from_str::<GeminiEvent>(line) else {
        return GeminiLine::KeepsSpeech(describe_unread_line(line));
    };

    match event {
        GeminiEvent::Init { session_id } => {
            GeminiLine::EndsSpeech(start_session(session_id))
        }
        GeminiEvent::Message { role, content } if role == ASSISTANT_ROLE => {
            GeminiLine::SpeechPart(content)
        }
        GeminiEvent::ToolUse {
            tool_name,
            parameters,
        } => {
            let description = describe_tool_use(
                &GEMINI_TOOLS,
                &tool_name,
                &parameters,
                task_folder,
            );
            GeminiLine::EndsSpeech(vec![AgentEvent::UsedTool(description)])
        }
        GeminiEvent::ToolResult {
            status,
            output,
            error,
        } => GeminiLine::EndsSpeech(describe_tool_result(
            &status, &output, &error,
        )),
        GeminiEvent::Error { message } => {
            let error = choose_given_text(&[&message], UNKNOWN_AGENT_ERROR);
            GeminiLine::EndsSpeech(vec![AgentEvent::ToolFailed(error)])
        }
        GeminiEvent::Result { status, error } => {
            GeminiLine::EndsSpeech(vec![describe_result(&status, &error)])
        }
        GeminiEvent::Message { .. } | GeminiEvent::Other => {
            GeminiLine::KeepsSpeech(Vec::new())
        }
    }
}

fn start_session(session_id: String) -> Vec<AgentEvent> {
    if session_id.trim().is_empty() {
        return Vec::new();
    }
    vec![AgentEvent::SessionStarted(session_id)]
}

fn describe_tool_result(
    status: &str,
    output: &str,
    error: &GeminiError,
) -> Vec<AgentEvent> {
    if status != ERROR_STATUS {
        return Vec::new();
    }
    let given_errors = [error.message.as_str(), output];
    let error_text = choose_given_text(&given_errors, UNKNOWN_TOOL_FAILURE);
    vec![AgentEvent::ToolFailed(error_text)]
}

fn describe_result(status: &str, error: &GeminiError) -> AgentEvent {
    if status == SUCCESS_STATUS {
        return AgentEvent::Finished;
    }
    let given_reasons = [error.message.as_str(), error.error_type.as_str()];
    let reason = choose_given_text(&given_reasons, UNKNOWN_FAILURE_REASON);
    AgentEvent::Failed(reason)
}

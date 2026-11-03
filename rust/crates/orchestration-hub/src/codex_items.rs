use serde::Deserialize;

use crate::agent_event::AgentEvent;
use crate::failure_texts::{
    UNKNOWN_AGENT_ERROR, UNKNOWN_TOOL_FAILURE, choose_given_text,
};
use crate::shell_commands::unwrap_shell_command;
use crate::tool_description::{
    DetailKind, ToolAction, describe_tool_action, name_tool,
};

const FAILED_STATUSES: [&str; 2] = ["failed", "declined"];
const RUN_COMMAND: ToolAction = ToolAction {
    tool_name: "shell",
    verb: "Ran",
    detail_kind: DetailKind::Text,
};
const SEARCH_THE_WEB: ToolAction = ToolAction {
    tool_name: "web_search",
    verb: "Searched the web for",
    detail_kind: DetailKind::Text,
};
const CHANGE_FILE: ToolAction = ToolAction {
    tool_name: "apply_patch",
    verb: "Changed",
    detail_kind: DetailKind::FilePath,
};
const FILE_CHANGE_VERBS: [(&str, &str); 3] = [
    ("add", "Wrote"),
    ("update", "Edited"),
    ("delete", "Deleted"),
];

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub(crate) enum CodexItem {
    AgentMessage {
        #[serde(default)]
        text: String,
    },
    CommandExecution {
        #[serde(default)]
        command: String,
        #[serde(default)]
        aggregated_output: String,
        #[serde(default)]
        status: String,
    },
    FileChange {
        #[serde(default)]
        changes: Vec<CodexFileChange>,
        #[serde(default)]
        status: String,
    },
    McpToolCall {
        #[serde(default)]
        tool: String,
        error: Option<CodexError>,
        #[serde(default)]
        status: String,
    },
    WebSearch {
        #[serde(default)]
        query: String,
    },
    Error {
        #[serde(default)]
        message: String,
    },
    #[serde(other)]
    Other,
}

#[derive(Debug, Deserialize)]
pub(crate) struct CodexFileChange {
    #[serde(default)]
    path: String,
    #[serde(default)]
    kind: String,
}

#[derive(Debug, Default, Deserialize)]
pub(crate) struct CodexError {
    #[serde(default)]
    pub(crate) message: String,
}

pub(crate) fn describe_started_item(
    item: &CodexItem,
    task_folder: &str,
) -> Vec<AgentEvent> {
    match item {
        CodexItem::CommandExecution { command, .. } => {
            let script = unwrap_shell_command(command);
            let description =
                describe_tool_action(RUN_COMMAND, script, task_folder);
            vec![AgentEvent::UsedTool(description)]
        }
        CodexItem::McpToolCall { tool, .. } => {
            vec![AgentEvent::UsedTool(name_tool(tool))]
        }
        _ => Vec::new(),
    }
}

pub(crate) fn describe_completed_item(
    item: &CodexItem,
    task_folder: &str,
) -> Vec<AgentEvent> {
    match item {
        CodexItem::AgentMessage { text } => describe_agent_message(text),
        CodexItem::CommandExecution {
            aggregated_output,
            status,
            ..
        } => describe_failure(status, aggregated_output),
        CodexItem::FileChange { changes, status } => {
            describe_file_changes(changes, status, task_folder)
        }
        CodexItem::McpToolCall { error, status, .. } => {
            let error_message = error
                .as_ref()
                .map(|error| error.message.as_str())
                .unwrap_or_default();
            describe_failure(status, error_message)
        }
        CodexItem::WebSearch { query } => {
            let description =
                describe_tool_action(SEARCH_THE_WEB, query, task_folder);
            vec![AgentEvent::UsedTool(description)]
        }
        CodexItem::Error { message } => {
            let error = choose_given_text(&[message], UNKNOWN_AGENT_ERROR);
            vec![AgentEvent::ToolFailed(error)]
        }
        CodexItem::Other => Vec::new(),
    }
}

fn describe_agent_message(text: &str) -> Vec<AgentEvent> {
    let said = text.trim();
    if said.is_empty() {
        return Vec::new();
    }
    vec![AgentEvent::Said(said.to_string())]
}

fn describe_failure(status: &str, error_text: &str) -> Vec<AgentEvent> {
    if !FAILED_STATUSES.contains(&status) {
        return Vec::new();
    }
    let error = choose_given_text(&[error_text], UNKNOWN_TOOL_FAILURE);
    vec![AgentEvent::ToolFailed(error)]
}

fn describe_file_changes(
    changes: &[CodexFileChange],
    status: &str,
    task_folder: &str,
) -> Vec<AgentEvent> {
    let mut events = Vec::new();
    for change in changes {
        let action = choose_file_change_action(&change.kind);
        let description =
            describe_tool_action(action, &change.path, task_folder);
        events.push(AgentEvent::UsedTool(description));
    }
    events.extend(describe_failure(status, ""));
    events
}

fn choose_file_change_action(kind: &str) -> ToolAction {
    let known_verb = FILE_CHANGE_VERBS
        .iter()
        .find(|(known_kind, _)| *known_kind == kind);
    let Some((_, verb)) = known_verb else {
        return CHANGE_FILE;
    };
    ToolAction {
        verb,
        ..CHANGE_FILE
    }
}

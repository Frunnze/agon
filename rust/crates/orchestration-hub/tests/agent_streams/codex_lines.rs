use proptest::prelude::*;
use serde_json::{Value, json};

use crate::stream_support::any_tool_detail;

pub type FileChangeVerb = (&'static str, &'static str);

pub const FILE_CHANGE_VERBS: [FileChangeVerb; 3] = [
    ("add", "Wrote"),
    ("update", "Edited"),
    ("delete", "Deleted"),
];
pub const FINISHED_STATUSES: [&str; 3] = ["completed", "failed", "declined"];

pub fn codex_event(event_type: &str) -> String {
    json!({"type": event_type}).to_string()
}

pub fn thread_started_line(thread: &str) -> String {
    json!({"type": "thread.started", "thread_id": thread}).to_string()
}

pub fn item_line(phase: &str, item: &Value) -> String {
    json!({"type": phase, "item": item}).to_string()
}

pub fn started_line(item: &Value) -> String {
    item_line("item.started", item)
}

pub fn completed_line(item: &Value) -> String {
    item_line("item.completed", item)
}

pub fn agent_message(text: &str) -> Value {
    json!({"id": "item_1", "type": "agent_message", "text": text})
}

pub fn command_item(command: &str, status: &str, output: &str) -> Value {
    json!({
        "id": "item_2",
        "type": "command_execution",
        "command": command,
        "aggregated_output": output,
        "exit_code": null,
        "status": status,
    })
}

pub fn file_change_item(changes: &[(String, String)], status: &str) -> Value {
    let mut rendered_changes = Vec::new();
    for (path, kind) in changes {
        rendered_changes.push(json!({"path": path, "kind": kind}));
    }
    json!({
        "id": "item_3",
        "type": "file_change",
        "changes": rendered_changes,
        "status": status,
    })
}

pub fn tool_call_item(tool: &str, status: &str, error: Option<&str>) -> Value {
    let error_field = error.map(|message| json!({"message": message}));
    json!({
        "id": "item_4",
        "type": "mcp_tool_call",
        "server": "github",
        "tool": tool,
        "arguments": {"owner": "agon"},
        "result": null,
        "error": error_field,
        "status": status,
    })
}

pub fn turn_failed_line(message: &str) -> String {
    json!({"type": "turn.failed", "error": {"message": message}}).to_string()
}

pub fn error_line_of(message: &str) -> String {
    json!({"type": "error", "message": message}).to_string()
}

pub fn any_finished_status() -> impl Strategy<Value = &'static str> {
    proptest::sample::select(FINISHED_STATUSES.to_vec())
}

pub fn any_file_change_kind() -> impl Strategy<Value = FileChangeVerb> {
    proptest::sample::select(FILE_CHANGE_VERBS.to_vec())
}

pub fn any_codex_line() -> impl Strategy<Value = String> {
    prop_oneof![
        any::<String>().prop_map(|thread| thread_started_line(&thread)),
        any::<String>().prop_map(|text| completed_line(&agent_message(&text))),
        (any_tool_detail(), any::<String>()).prop_map(|(command, output)| {
            started_line(&command_item(&command, "in_progress", &output))
        }),
        (any_tool_detail(), any_finished_status(), any::<String>()).prop_map(
            |(command, status, output)| {
                completed_line(&command_item(&command, status, &output))
            }
        ),
        any::<String>().prop_map(|message| turn_failed_line(&message)),
        any::<String>().prop_map(|message| error_line_of(&message)),
        Just(codex_event("turn.started")),
        Just(codex_event("turn.completed")),
    ]
}

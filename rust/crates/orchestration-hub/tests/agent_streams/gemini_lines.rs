use proptest::prelude::*;
use serde_json::{Value, json};

use crate::stream_support::any_tool_detail;

pub type GeminiTool = (&'static str, &'static str, &'static str);

pub const GEMINI_FILE_TOOLS: [GeminiTool; 4] = [
    ("read_file", "file_path", "Read"),
    ("write_file", "file_path", "Wrote"),
    ("replace", "file_path", "Edited"),
    ("list_directory", "dir_path", "Listed"),
];

pub const GEMINI_TEXT_TOOLS: [GeminiTool; 4] = [
    ("run_shell_command", "command", "Ran"),
    ("grep_search", "pattern", "Searched for"),
    ("glob", "pattern", "Looked for files matching"),
    ("google_web_search", "query", "Searched the web for"),
];

const TIMESTAMP: &str = "2026-10-30T09:12:01.512Z";

pub fn init_line(session: &str) -> String {
    json!({
        "type": "init",
        "timestamp": TIMESTAMP,
        "session_id": session,
        "model": "gemini-2.5-pro",
    })
    .to_string()
}

pub fn message_line(role: &str, content: &str) -> String {
    json!({
        "type": "message",
        "timestamp": TIMESTAMP,
        "role": role,
        "content": content,
        "delta": true,
    })
    .to_string()
}

pub fn speech_lines(parts: &[String]) -> Vec<String> {
    let mut lines = Vec::new();
    for part in parts {
        lines.push(message_line("assistant", part));
    }
    lines
}

pub fn tool_use_line(tool_name: &str, parameters: &Value) -> String {
    json!({
        "type": "tool_use",
        "timestamp": TIMESTAMP,
        "tool_name": tool_name,
        "tool_id": format!("{tool_name}-1761815523402-0"),
        "parameters": parameters,
    })
    .to_string()
}

pub fn tool_result_line(
    status: &str,
    output: Option<&str>,
    error_message: Option<&str>,
) -> String {
    let mut line = json!({
        "type": "tool_result",
        "timestamp": TIMESTAMP,
        "tool_id": "read_file-1761815523402-0",
        "status": status,
    });
    if let Some(output) = output {
        line["output"] = json!(output);
    }
    if let Some(message) = error_message {
        line["error"] = json!({"type": "tool_error", "message": message});
    }
    line.to_string()
}

pub fn error_event_line(severity: &str, message: &str) -> String {
    json!({
        "type": "error",
        "timestamp": TIMESTAMP,
        "severity": severity,
        "message": message,
    })
    .to_string()
}

pub fn result_line(status: &str, error: Option<(&str, &str)>) -> String {
    let mut line = json!({
        "type": "result",
        "timestamp": TIMESTAMP,
        "status": status,
        "stats": {"total_tokens": 8123, "duration_ms": 9099},
    });
    if let Some((error_type, message)) = error {
        line["error"] = json!({"type": error_type, "message": message});
    }
    line.to_string()
}

pub fn finished_line() -> String {
    result_line("success", None)
}

pub fn known_gemini_tools() -> Vec<GeminiTool> {
    let mut tools = GEMINI_FILE_TOOLS.to_vec();
    tools.extend(GEMINI_TEXT_TOOLS);
    tools
}

pub fn any_speech_parts() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::vec(any::<String>(), 1..6)
}

pub fn any_gemini_line() -> impl Strategy<Value = String> {
    prop_oneof![
        any::<String>().prop_map(|session| init_line(&session)),
        any::<String>().prop_map(|text| message_line("assistant", &text)),
        any::<String>().prop_map(|text| message_line("user", &text)),
        any_tool_detail().prop_map(|command| {
            tool_use_line("run_shell_command", &json!({"command": command}))
        }),
        (any::<String>(), any::<String>()).prop_map(|(output, message)| {
            tool_result_line("error", Some(&output), Some(&message))
        }),
        any::<String>()
            .prop_map(|message| error_event_line("error", &message)),
        any::<String>().prop_map(|message| {
            result_line("error", Some(("api_error", &message)))
        }),
        Just(finished_line()),
    ]
}

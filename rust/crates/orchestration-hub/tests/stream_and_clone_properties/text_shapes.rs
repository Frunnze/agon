use orchestration_core::workflow::AgentKind;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::Index;
use serde_json::json;

use crate::claude_lines::assistant_line;
use crate::claude_tool_results::{
    ToolOutcome, ToolResultContent, tool_result_line,
};
use crate::codex_lines::{
    agent_message, command_item, completed_line, error_line_of, started_line,
    turn_failed_line,
};
use crate::gemini_lines::{
    error_event_line, finished_line, message_line, result_line, tool_use_line,
};

const LARGEST_CODE_COUNT: usize = 5;

pub type TextLines = fn(&str) -> Vec<String>;
pub type TextShape = (AgentKind, TextLines);

const TEXT_SHAPES: [TextShape; 13] = [
    (AgentKind::ClaudeCode, claude_said),
    (AgentKind::ClaudeCode, claude_command),
    (AgentKind::ClaudeCode, claude_tool_failure),
    (AgentKind::ClaudeCode, claude_turn_failure),
    (AgentKind::Codex, codex_said),
    (AgentKind::Codex, codex_command),
    (AgentKind::Codex, codex_command_failure),
    (AgentKind::Codex, codex_error),
    (AgentKind::Codex, codex_turn_failure),
    (AgentKind::GeminiCli, gemini_said),
    (AgentKind::GeminiCli, gemini_command),
    (AgentKind::GeminiCli, gemini_error),
    (AgentKind::GeminiCli, gemini_turn_failure),
];

pub fn any_text_shape() -> impl Strategy<Value = TextShape> {
    proptest::sample::select(TEXT_SHAPES.to_vec())
}

pub fn any_colour_code() -> impl Strategy<Value = String> {
    prop_oneof![
        "\u{1b}\\[[0-9;]{0,8}m",
        "\u{1b}\\[[0-9]{0,3}[ABCDGHJK]",
        "\u{1b}\\]8;;[a-z:/.]{0,12}\u{7}",
        "\u{1b}\\]0;[a-z ]{0,10}\u{1b}\\\\",
    ]
}

pub fn any_code_placements(
    code: impl Strategy<Value = String>,
) -> impl Strategy<Value = Vec<(Index, String)>> {
    vec((any::<Index>(), code), 1..LARGEST_CODE_COUNT)
}

pub fn insert_codes(text: &str, placements: &[(Index, String)]) -> String {
    let characters: Vec<char> = text.chars().collect();
    let mut codes_before = vec![String::new(); characters.len() + 1];
    for (position, code) in placements {
        let slot = position.index(codes_before.len());
        codes_before[slot].push_str(code);
    }

    let mut coloured = String::new();
    for (slot, character) in characters.iter().enumerate() {
        coloured.push_str(&codes_before[slot]);
        coloured.push(*character);
    }
    coloured.push_str(&codes_before[characters.len()]);
    coloured
}

fn claude_said(text: &str) -> Vec<String> {
    vec![assistant_line(&json!([{"type": "text", "text": text}]))]
}

fn claude_command(text: &str) -> Vec<String> {
    let tool_use = json!({
        "type": "tool_use",
        "name": "Bash",
        "input": {"command": text},
    });
    vec![assistant_line(&json!([tool_use]))]
}

fn claude_tool_failure(text: &str) -> Vec<String> {
    let content = ToolResultContent::Plain(text.to_owned());
    vec![tool_result_line(&content, ToolOutcome::Failed)]
}

fn claude_turn_failure(text: &str) -> Vec<String> {
    let line = json!({
        "type": "result",
        "subtype": "error_during_execution",
        "is_error": true,
        "result": text,
    });
    vec![line.to_string()]
}

fn codex_said(text: &str) -> Vec<String> {
    vec![completed_line(&agent_message(text))]
}

fn codex_command(text: &str) -> Vec<String> {
    vec![started_line(&command_item(text, "in_progress", ""))]
}

fn codex_command_failure(text: &str) -> Vec<String> {
    vec![completed_line(&command_item("cargo test", "failed", text))]
}

fn codex_error(text: &str) -> Vec<String> {
    vec![error_line_of(text)]
}

fn codex_turn_failure(text: &str) -> Vec<String> {
    vec![turn_failed_line(text)]
}

fn gemini_said(text: &str) -> Vec<String> {
    vec![message_line("assistant", text), finished_line()]
}

fn gemini_command(text: &str) -> Vec<String> {
    let parameters = json!({"command": text});
    vec![tool_use_line("run_shell_command", &parameters)]
}

fn gemini_error(text: &str) -> Vec<String> {
    vec![error_event_line("error", text)]
}

fn gemini_turn_failure(text: &str) -> Vec<String> {
    vec![result_line("error", Some(("api_error", text)))]
}

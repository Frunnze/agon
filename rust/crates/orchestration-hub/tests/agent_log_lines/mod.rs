use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_log::{AgentLogLine, describe_agent_log_lines};
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::agent_reading::parse_agent_line;
use crate::claude_lines::{any_detail, assistant_line, parse_claude};
use crate::claude_tool_results::{
    ToolOutcome, any_tool_result_content, tool_result_line,
};
use crate::json_texts::join_words;

const MAXIMUM_LOG_TEXT_CHARACTERS: usize = 120;
const SHORTENED_MARKER: char = '…';

#[derive(Clone, Copy, Debug)]
pub enum Ending {
    Finished,
    Failed,
}

pub fn any_agent() -> impl Strategy<Value = AgentKind> {
    prop_oneof![
        Just(AgentKind::ClaudeCode),
        Just(AgentKind::Codex),
        Just(AgentKind::GeminiCli),
    ]
}

pub fn any_ending() -> impl Strategy<Value = Ending> {
    prop_oneof![Just(Ending::Finished), Just(Ending::Failed)]
}

pub fn any_outcome() -> impl Strategy<Value = ToolOutcome> {
    prop_oneof![Just(ToolOutcome::Failed), Just(ToolOutcome::Succeeded)]
}

pub fn has_content(text: &str) -> bool {
    !text.trim().is_empty()
}

pub fn describe_log(agent: AgentKind, line: &str) -> Vec<AgentLogLine> {
    let agent_events = parse_agent_line(agent, line);
    describe_agent_log_lines(line, &agent_events)
}

pub fn describe_claude_log(line: &str) -> Vec<AgentLogLine> {
    describe_agent_log_lines(line, &parse_claude(line))
}

pub fn normal_line(text: &str) -> AgentLogLine {
    AgentLogLine {
        text: text.to_string(),
        is_error: false,
    }
}

pub fn error_line(text: &str) -> AgentLogLine {
    AgentLogLine {
        text: text.to_string(),
        is_error: true,
    }
}

pub fn is_shortened_from(shown: &str, original: &str) -> bool {
    let collapsed = join_words(original);
    if collapsed.chars().count() <= MAXIMUM_LOG_TEXT_CHARACTERS {
        return shown == collapsed;
    }

    let Some(kept) = shown.strip_suffix(SHORTENED_MARKER) else {
        return false;
    };
    let is_short = kept.chars().count() <= MAXIMUM_LOG_TEXT_CHARACTERS;
    is_short && !kept.is_empty() && collapsed.starts_with(kept)
}

pub fn said_line(text: &str) -> String {
    assistant_line(&json!([{"type": "text", "text": text}]))
}

pub fn bash_line(command: &str) -> String {
    let tool_use = json!({
        "type": "tool_use",
        "name": "Bash",
        "input": {"command": command},
    });
    assistant_line(&Value::Array(vec![tool_use]))
}

pub fn init_line(session: &str) -> String {
    json!({"type": "system", "subtype": "init", "session_id": session})
        .to_string()
}

pub fn result_line(ending: Ending, result_text: &str) -> String {
    let (subtype, is_error) = match ending {
        Ending::Finished => ("success", false),
        Ending::Failed => ("error_during_execution", true),
    };
    json!({
        "type": "result",
        "subtype": subtype,
        "is_error": is_error,
        "result": result_text,
    })
    .to_string()
}

pub fn any_stream_json_line() -> impl Strategy<Value = String> {
    prop_oneof![
        any::<String>().prop_map(|session| init_line(&session)),
        any::<String>().prop_map(|text| said_line(&text)),
        any_detail().prop_map(|command| bash_line(&command)),
        (any_tool_result_content(), any_outcome()).prop_map(
            |(content, outcome)| tool_result_line(&content, outcome)
        ),
        (any_ending(), any::<String>()).prop_map(|(ending, result_text)| {
            result_line(ending, &result_text)
        }),
    ]
}

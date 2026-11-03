mod agent_reading;

use agent_reading::parse_agent_line;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;
use serde_json::Value;

const CLAUDE_STREAM: &str = include_str!("fixtures/claude_stream.jsonl");
const CODEX_STREAM: &str = include_str!("fixtures/codex_stream.jsonl");
const GEMINI_STREAM: &str = include_str!("fixtures/gemini_stream.jsonl");

const JSON_KEYS: [&str; 26] = [
    "type",
    "subtype",
    "message",
    "content",
    "text",
    "name",
    "input",
    "command",
    "file_path",
    "result",
    "is_error",
    "session_id",
    "thinking",
    "thread_id",
    "item",
    "aggregated_output",
    "status",
    "changes",
    "path",
    "kind",
    "error",
    "role",
    "tool_name",
    "parameters",
    "output",
    "query",
];

const JSON_WORDS: [&str; 26] = [
    "system",
    "init",
    "assistant",
    "result",
    "text",
    "tool_use",
    "thinking",
    "success",
    "Bash",
    "Edit",
    "user",
    "thread.started",
    "item.started",
    "item.completed",
    "turn.completed",
    "turn.failed",
    "agent_message",
    "command_execution",
    "file_change",
    "mcp_tool_call",
    "failed",
    "message",
    "tool_result",
    "error",
    "replace",
    "update",
];

fn any_agent() -> impl Strategy<Value = AgentKind> {
    prop_oneof![
        Just(AgentKind::ClaudeCode),
        Just(AgentKind::Codex),
        Just(AgentKind::GeminiCli),
    ]
}

fn any_json_key() -> impl Strategy<Value = String> {
    prop_oneof![
        proptest::sample::select(JSON_KEYS.to_vec()).prop_map(String::from),
        any::<String>(),
    ]
}

fn any_json_leaf() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        any::<bool>().prop_map(Value::Bool),
        any::<i64>().prop_map(Value::from),
        any::<f64>().prop_map(Value::from),
        proptest::sample::select(JSON_WORDS.to_vec()).prop_map(Value::from),
        any::<String>().prop_map(Value::String),
    ]
}

fn any_json() -> impl Strategy<Value = Value> {
    any_json_leaf().prop_recursive(5, 48, 6, |inner| {
        prop_oneof![
            proptest::collection::vec(inner.clone(), 0..4)
                .prop_map(Value::Array),
            proptest::collection::btree_map(any_json_key(), inner, 0..6)
                .prop_map(|fields| Value::Object(
                    fields.into_iter().collect()
                )),
        ]
    })
}

fn has_only_meaningful_text(events: &[AgentEvent]) -> bool {
    events.iter().all(|event| match event {
        AgentEvent::Said(text)
        | AgentEvent::UsedTool(text)
        | AgentEvent::ToolFailed(text)
        | AgentEvent::Failed(text)
        | AgentEvent::SessionStarted(text) => !text.trim().is_empty(),
        AgentEvent::Finished | AgentEvent::AskedForApproval(_) => true,
    })
}

fn any_recorded_stream() -> impl Strategy<Value = (AgentKind, &'static str)> {
    prop_oneof![
        Just((AgentKind::ClaudeCode, CLAUDE_STREAM)),
        Just((AgentKind::Codex, CODEX_STREAM)),
        Just((AgentKind::GeminiCli, GEMINI_STREAM)),
    ]
}

fn mutate_line(line: &str, cut: usize, insertion: &str) -> String {
    let characters: Vec<char> = line.chars().collect();
    let cut_position = cut % (characters.len() + 1);
    let head: String = characters[..cut_position].iter().collect();
    let tail: String = characters[cut_position..].iter().collect();
    format!("{head}{insertion}{tail}")
}

proptest! {
    #[test]
    fn test_parse_agent_line_property_arbitrary_text_never_panics(
        agent in any_agent(),
        line in any::<String>(),
    ) {
        let events = parse_agent_line(agent, &line);

        prop_assert!(has_only_meaningful_text(&events));
    }

    #[test]
    fn test_parse_agent_line_property_arbitrary_json_never_panics(
        agent in any_agent(),
        value in any_json(),
    ) {
        let events = parse_agent_line(agent, &value.to_string());

        prop_assert!(has_only_meaningful_text(&events));
    }

    #[test]
    fn test_parse_agent_line_property_mutated_stream_lines_never_panic(
        (agent, stream) in any_recorded_stream(),
        line_index in any::<usize>(),
        cut in any::<usize>(),
        insertion in prop_oneof![
            any::<String>(),
            Just("\"".to_string()),
            Just("}".to_string()),
            Just("\\u".to_string()),
            Just("\n".to_string()),
        ],
    ) {
        let lines: Vec<&str> = stream.lines().collect();
        let line = lines[line_index % lines.len()];
        let mutated = mutate_line(line, cut, &insertion);

        let events = parse_agent_line(agent, &mutated);

        prop_assert!(has_only_meaningful_text(&events));
    }

    #[test]
    fn test_parse_agent_line_property_truncated_lines_never_panic(
        (agent, stream) in any_recorded_stream(),
        line_index in any::<usize>(),
        cut in any::<usize>(),
    ) {
        let lines: Vec<&str> = stream.lines().collect();
        let line = lines[line_index % lines.len()];
        let kept_characters = cut % (line.chars().count() + 1);
        let truncated: String = line.chars().take(kept_characters).collect();

        let events = parse_agent_line(agent, &truncated);

        prop_assert!(has_only_meaningful_text(&events));
    }
}

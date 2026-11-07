use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::agent_reading::parse_agent_line;
use crate::codex_lines::any_codex_line;
use crate::command_support::{ALL_AGENTS, any_agent};
use crate::gemini_lines::any_gemini_line;
use crate::json_texts::reads_as_json;

const HUGE_LINE_CHARACTERS: usize = 200_000;
const ESCAPE: char = '\u{1b}';
const CLAUDE_MALFORMED_LINES: [&str; 5] = [
    r#"{"type":"assistant","message":{"content":"plain text"}}"#,
    r#"{"type":"assistant","message":{"content":[{"type":"text"}]}}"#,
    r#"{"type":"assistant"}"#,
    r#"{"type":"system","subtype":"init","session_id":5}"#,
    r#"{"type":"result","subtype":"success","is_error":"no"}"#,
];
const CODEX_MALFORMED_LINES: [&str; 4] = [
    r#"{"type":"thread.started","thread_id":5}"#,
    r#"{"type":"thread.started"}"#,
    r#"{"type":"item.completed","item":"agent_message"}"#,
    r#"{"type":"turn.failed","error":"boom"}"#,
];
const GEMINI_MALFORMED_LINES: [&str; 4] = [
    r#"{"type":"init","session_id":5}"#,
    r#"{"type":"message","role":"assistant","content":["a"]}"#,
    r#"{"type":"tool_use","tool_name":7}"#,
    r#"{"type":"result","status":false}"#,
];

fn any_untyped_json_line() -> impl Strategy<Value = String> {
    prop_oneof![
        any::<String>().prop_map(|text| json!({"session_id": text})),
        any::<String>().prop_map(|text| json!({"text": text, "type": 5})),
        any::<String>().prop_map(|text| json!([text, 1, null])),
        any::<String>().prop_map(|text| json!({"type": null, "text": text})),
        Just(json!({})),
        Just(json!([])),
    ]
    .prop_map(|line: Value| line.to_string())
}

fn malformed_lines_of(agent: AgentKind) -> Vec<&'static str> {
    match agent {
        AgentKind::ClaudeCode => CLAUDE_MALFORMED_LINES.to_vec(),
        AgentKind::Codex => CODEX_MALFORMED_LINES.to_vec(),
        AgentKind::GeminiCli => GEMINI_MALFORMED_LINES.to_vec(),
    }
}

fn any_known_line() -> impl Strategy<Value = (AgentKind, String)> {
    let claude_line = any::<String>().prop_map(|session| {
        json!({"type": "system", "subtype": "init", "session_id": session})
            .to_string()
    });
    prop_oneof![
        claude_line.prop_map(|line| (AgentKind::ClaudeCode, line)),
        any_codex_line().prop_map(|line| (AgentKind::Codex, line)),
        any_gemini_line().prop_map(|line| (AgentKind::GeminiCli, line)),
    ]
}

fn coloured(line: &str) -> String {
    format!("{ESCAPE}[2K{ESCAPE}[32m{line}{ESCAPE}[0m\r")
}

proptest! {
    #[test]
    fn test_read_line_property_untyped_json_never_reaches_any_chat(
        line in any_untyped_json_line(),
    ) {
        for agent in ALL_AGENTS {
            let agent_events = parse_agent_line(agent, &line);
            prop_assert_eq!(agent_events, Vec::new(), "{:?}", agent);
        }
    }

    #[test]
    fn test_read_line_property_malformed_known_lines_give_nothing(
        agent in any_agent(),
        pick in any::<prop::sample::Index>(),
    ) {
        let malformed_lines = malformed_lines_of(agent);
        let line = pick.get(&malformed_lines);

        prop_assert_eq!(parse_agent_line(agent, line), Vec::new());
    }

    #[test]
    fn test_read_line_property_plain_lines_read_alike(
        line in "\\PC{1,60}",
    ) {
        prop_assume!(!reads_as_json(&line));

        let printed = line.trim_end();
        let mut expected = Vec::new();
        if !printed.trim_start().is_empty() {
            expected.push(AgentEvent::Said(printed.to_owned()));
        }
        for agent in ALL_AGENTS {
            prop_assert_eq!(parse_agent_line(agent, &line), expected.clone());
        }
    }

    #[test]
    fn test_read_line_property_huge_lines_stay_whole(
        agent in any_agent(),
        piece in "[a-zé中😀 ]{1,8}x",
    ) {
        let repeat_count = HUGE_LINE_CHARACTERS / piece.chars().count();
        let line = piece.repeat(repeat_count);

        let agent_events = parse_agent_line(agent, &line);

        prop_assert_eq!(agent_events, vec![AgentEvent::Said(line)]);
    }

    #[test]
    fn test_read_line_property_coloured_lines_read_like_bare_ones(
        (agent, line) in any_known_line(),
    ) {
        let bare_events = parse_agent_line(agent, &line);
        let coloured_events = parse_agent_line(agent, &coloured(&line));

        prop_assert_eq!(coloured_events, bare_events);
    }
}

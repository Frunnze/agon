use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;
use serde_json::json;

use crate::agent_log_lines::init_line;
use crate::agent_reading::parse_agent_line;
use crate::codex_lines::{codex_event, thread_started_line, turn_failed_line};
use crate::gemini_lines;
use crate::stream_support::{UNKNOWN_FAILURE_REASON, expect_given_text};

const KNOWN_EVENT_TYPES: [&str; 6] = [
    "thread.started",
    "item.started",
    "item.completed",
    "turn.completed",
    "turn.failed",
    "error",
];
const BLANK_TEXTS: [&str; 5] = ["", " ", "\t\n", "\u{a0}\u{3000}", "\r\n "];

fn parse_codex(line: &str) -> Vec<AgentEvent> {
    parse_agent_line(AgentKind::Codex, line)
}

fn any_blank_text() -> impl Strategy<Value = &'static str> {
    proptest::sample::select(BLANK_TEXTS.to_vec())
}

fn any_session_id() -> impl Strategy<Value = String> {
    prop_oneof![
        any::<String>(),
        any_blank_text().prop_map(String::from),
        "[ \t]{0,2}[a-f0-9-]{1,36}[ \t]{0,2}",
    ]
}

proptest! {
    #[test]
    fn test_parse_codex_line_property_turn_completed_finishes(
        input_tokens in any::<u32>(),
        output_tokens in any::<u32>(),
    ) {
        let line = json!({
            "type": "turn.completed",
            "usage": {
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
            },
        });

        let agent_events = parse_codex(&line.to_string());

        prop_assert_eq!(agent_events, vec![AgentEvent::Finished]);
    }

    #[test]
    fn test_parse_codex_line_property_turn_failure_reason_is_trimmed(
        message in any::<String>(),
        padding in "[ \n\t]{0,3}",
    ) {
        let padded = format!("{padding}{message}{padding}");

        let agent_events = parse_codex(&turn_failed_line(&padded));
        let unexplained = parse_codex(&codex_event("turn.failed"));

        let reason = expect_given_text(&message, UNKNOWN_FAILURE_REASON);
        prop_assert_eq!(agent_events, vec![AgentEvent::Failed(reason)]);
        let unknown = AgentEvent::Failed(UNKNOWN_FAILURE_REASON.to_owned());
        prop_assert_eq!(unexplained, vec![unknown]);
    }

    #[test]
    fn test_parse_codex_line_property_unknown_event_types_give_nothing(
        event_type in "[a-z_.]{1,16}",
        text in any::<String>(),
    ) {
        prop_assume!(!KNOWN_EVENT_TYPES.contains(&event_type.as_str()));
        let line = json!({"type": event_type, "message": text, "text": text});

        prop_assert_eq!(parse_codex(&line.to_string()), Vec::new());
    }

    #[test]
    fn test_start_session_property_keeps_the_thread_id(
        thread_id in any::<String>(),
    ) {
        prop_assume!(!thread_id.trim().is_empty());

        let agent_events = parse_codex(&thread_started_line(&thread_id));

        let expected = AgentEvent::SessionStarted(thread_id);
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_start_session_property_blank_threads_start_nothing(
        blank in any_blank_text(),
    ) {
        prop_assert_eq!(parse_codex(&thread_started_line(blank)), Vec::new());
    }

    #[test]
    fn test_start_session_property_agents_agree_on_session_ids(
        session in any_session_id(),
    ) {
        let claude_events =
            parse_agent_line(AgentKind::ClaudeCode, &init_line(&session));
        let codex_events = parse_codex(&thread_started_line(&session));
        let gemini_line = gemini_lines::init_line(&session);
        let gemini_events =
            parse_agent_line(AgentKind::GeminiCli, &gemini_line);

        prop_assert_eq!(&codex_events, &claude_events);
        prop_assert_eq!(&gemini_events, &claude_events);
    }
}

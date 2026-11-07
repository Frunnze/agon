use orchestration_core::workflow::AgentKind;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::json;

use crate::event_queries::{chat_texts, log_texts};
use crate::speech_relay_support::{
    SAID_PREFIX, any_speech_parts, gemini_speech_lines, join_speech,
    relay_until_output_ends,
};
use crate::support::to_case_error;

const RELAY_CASES: u32 = 48;
const LARGEST_TURN_COUNT: usize = 4;

type SpeechAndCommand = (Vec<String>, String);

fn any_command() -> impl Strategy<Value = String> {
    "[a-z][a-z0-9 ]{0,10}[a-z0-9]"
}

fn any_printed_line() -> impl Strategy<Value = String> {
    "[a-zA-Z][a-zA-Z0-9 .:]{0,30}[a-zA-Z0-9.]"
}

fn any_agent() -> impl Strategy<Value = AgentKind> {
    prop_oneof![
        Just(AgentKind::ClaudeCode),
        Just(AgentKind::Codex),
        Just(AgentKind::GeminiCli),
    ]
}

fn any_turn() -> impl Strategy<Value = SpeechAndCommand> {
    (any_speech_parts(), any_command())
}

fn gemini_shell_line(command: &str) -> String {
    json!({
        "type": "tool_use",
        "tool_name": "run_shell_command",
        "parameters": {"command": command},
    })
    .to_string()
}

fn build_turn_lines(
    turns: &[SpeechAndCommand],
    last_parts: &[String],
) -> Vec<String> {
    let mut lines = Vec::new();
    for (parts, command) in turns {
        lines.extend(gemini_speech_lines(parts));
        lines.push(gemini_shell_line(command));
    }
    lines.extend(gemini_speech_lines(last_parts));
    lines
}

fn expect_turn_texts(
    turns: &[SpeechAndCommand],
    last_parts: &[String],
    said_prefix: &str,
) -> Vec<String> {
    let mut texts = Vec::new();
    for (parts, command) in turns {
        texts.push(format!("{said_prefix}{}", join_speech(parts)));
        texts.push(format!("Ran {command}"));
    }
    texts.push(format!("{said_prefix}{}", join_speech(last_parts)));
    texts
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RELAY_CASES))]

    #[test]
    fn test_describe_relayed_events_property_chat_keeps_the_agent_order(
        turns in vec(any_turn(), 0..LARGEST_TURN_COUNT),
        last_parts in any_speech_parts(),
    ) {
        let lines = build_turn_lines(&turns, &last_parts);

        let (_ending, events) =
            relay_until_output_ends(AgentKind::GeminiCli, &lines)
                .map_err(to_case_error)?;

        let expected = expect_turn_texts(&turns, &last_parts, "");
        prop_assert_eq!(chat_texts(&events), expected);
    }

    #[test]
    fn test_describe_relayed_events_property_log_keeps_the_agent_order(
        turns in vec(any_turn(), 0..LARGEST_TURN_COUNT),
        last_parts in any_speech_parts(),
    ) {
        let lines = build_turn_lines(&turns, &last_parts);

        let (_ending, events) =
            relay_until_output_ends(AgentKind::GeminiCli, &lines)
                .map_err(to_case_error)?;

        let expected = expect_turn_texts(&turns, &last_parts, SAID_PREFIX);
        prop_assert_eq!(log_texts(&events), expected);
    }

    #[test]
    fn test_describe_relayed_events_property_quiet_ends_add_nothing(
        agent in any_agent(),
        printed_lines in vec(any_printed_line(), 0..6),
    ) {
        let (_ending, events) = relay_until_output_ends(agent, &printed_lines)
            .map_err(to_case_error)?;

        prop_assert_eq!(events.len(), printed_lines.len() * 2);
        prop_assert_eq!(&log_texts(&events), &printed_lines);
        prop_assert_eq!(&chat_texts(&events), &printed_lines);
    }
}

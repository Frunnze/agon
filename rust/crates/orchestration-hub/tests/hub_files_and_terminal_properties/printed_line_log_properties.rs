use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_log::{
    describe_agent_event_log_lines, describe_agent_log_lines,
};
use proptest::prelude::*;

use crate::gemini_lines::{finished_line, message_line, speech_lines};
use crate::gemini_reading::{any_printed_line, any_speech_parts};
use crate::json_texts::join_words;
use crate::log_support::{JSON_LINE, SAID_PREFIX, any_agent_events};
use crate::stream_support::{describe_container_log, normal_line};

fn any_agent() -> impl Strategy<Value = AgentKind> {
    prop_oneof![
        Just(AgentKind::ClaudeCode),
        Just(AgentKind::Codex),
        Just(AgentKind::GeminiCli),
    ]
}

fn said_line(parts: &[String]) -> String {
    format!("{SAID_PREFIX}{}", join_words(&parts.concat()))
}

proptest! {
    #[test]
    fn test_describe_printed_line_property_logs_ended_speech_first(
        parts in any_speech_parts(),
        printed in any_printed_line(),
    ) {
        let mut lines = speech_lines(&parts);
        lines.push(printed.clone());
        lines.push(finished_line());

        let log_lines = describe_container_log(AgentKind::GeminiCli, &lines);

        let expected = vec![
            normal_line(&said_line(&parts)),
            normal_line(&printed),
            normal_line("Finished"),
        ];
        prop_assert_eq!(log_lines, expected);
    }

    #[test]
    fn test_describe_printed_line_property_lone_lines_stay_as_printed(
        agent in any_agent(),
        printed_lines in proptest::collection::vec(any_printed_line(), 0..6),
    ) {
        let log_lines = describe_container_log(agent, &printed_lines);

        let mut expected = Vec::new();
        for printed in &printed_lines {
            expected.push(normal_line(printed));
        }
        prop_assert_eq!(log_lines, expected);
    }

    #[test]
    fn test_describe_printed_line_property_speech_like_the_line_stays(
        printed in any_printed_line(),
    ) {
        let lines = vec![message_line("assistant", &printed), printed.clone()];

        let log_lines = describe_container_log(AgentKind::GeminiCli, &lines);

        let said = format!("{SAID_PREFIX}{}", join_words(&printed));
        let expected = vec![normal_line(&said), normal_line(&printed)];
        prop_assert_eq!(log_lines, expected);
    }

    #[test]
    fn test_describe_agent_event_log_lines_property_matches_json_lines(
        agent_events in any_agent_events(),
    ) {
        let log_lines = describe_agent_event_log_lines(&agent_events);

        let json_line_log = describe_agent_log_lines(JSON_LINE, &agent_events);
        prop_assert_eq!(log_lines, json_line_log);
    }

    #[test]
    fn test_describe_agent_event_log_lines_property_splits_like_the_events(
        first_events in any_agent_events(),
        second_events in any_agent_events(),
    ) {
        let all_events =
            [first_events.clone(), second_events.clone()].concat();

        let log_lines = describe_agent_event_log_lines(&all_events);

        let mut expected = describe_agent_event_log_lines(&first_events);
        expected.extend(describe_agent_event_log_lines(&second_events));
        prop_assert!(log_lines.len() <= all_events.len());
        prop_assert_eq!(log_lines, expected);
    }

    #[test]
    fn test_describe_agent_event_log_lines_property_speech_gets_the_prefix(
        parts in any_speech_parts(),
    ) {
        let speech = parts.concat();
        let agent_events = vec![AgentEvent::Said(speech.trim().to_owned())];

        let log_lines = describe_agent_event_log_lines(&agent_events);

        prop_assert_eq!(log_lines, vec![normal_line(&said_line(&parts))]);
    }
}

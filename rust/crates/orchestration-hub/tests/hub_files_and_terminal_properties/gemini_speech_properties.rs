use std::path::Path;

use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_output::AgentOutputReader;
use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::json;

use crate::gemini_lines::{
    finished_line, init_line, speech_lines, tool_use_line,
};
use crate::gemini_reading::{
    any_printed_line, any_speech_parts, read_gemini, said_speech,
};

const LARGEST_LINE_COUNT: usize = 8;

fn read_then_end(
    agent: AgentKind,
    lines: &[String],
) -> (Vec<AgentEvent>, Vec<AgentEvent>) {
    let task_folder = Path::new(CONTAINER_WORKSPACE_DIRECTORY);
    let mut reader = AgentOutputReader::new(agent, task_folder);
    let mut line_events = Vec::new();
    for line in lines {
        let (next_reader, agent_events) = reader.read_line(line);
        reader = next_reader;
        line_events.extend(agent_events);
    }
    (line_events, reader.read_end_of_output())
}

fn any_speech_ending_line() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(finished_line()),
        Just(init_line("c2a9e3f1")),
        Just(tool_use_line("glob", &json!({"pattern": "*.rs"}))),
        any_printed_line(),
    ]
}

fn any_other_agent() -> impl Strategy<Value = AgentKind> {
    prop_oneof![Just(AgentKind::ClaudeCode), Just(AgentKind::Codex)]
}

proptest! {
    #[test]
    fn test_read_unread_line_property_printed_line_follows_earlier_speech(
        parts in any_speech_parts(),
        printed in any_printed_line(),
    ) {
        let mut lines = speech_lines(&parts);
        lines.push(printed.clone());
        lines.push(finished_line());

        let agent_events = read_gemini(&lines);

        let mut expected = said_speech(&parts);
        expected.push(AgentEvent::Said(printed));
        expected.push(AgentEvent::Finished);
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_read_unread_line_property_printed_line_splits_the_speech(
        earlier_parts in any_speech_parts(),
        printed in any_printed_line(),
        later_parts in any_speech_parts(),
    ) {
        let mut lines = speech_lines(&earlier_parts);
        lines.push(printed.clone());
        lines.extend(speech_lines(&later_parts));
        lines.push(finished_line());

        let agent_events = read_gemini(&lines);

        let mut expected = said_speech(&earlier_parts);
        expected.push(AgentEvent::Said(printed));
        expected.extend(said_speech(&later_parts));
        expected.push(AgentEvent::Finished);
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_read_unread_line_property_printed_lines_keep_their_order(
        printed_lines in vec(any_printed_line(), 0..LARGEST_LINE_COUNT),
    ) {
        let agent_events = read_gemini(&printed_lines);

        let mut expected = Vec::new();
        for printed in &printed_lines {
            expected.push(AgentEvent::Said(printed.clone()));
        }
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_read_end_of_output_property_gives_the_waiting_speech(
        has_session in any::<bool>(),
        parts in any_speech_parts(),
    ) {
        let mut lines = Vec::new();
        if has_session {
            lines.push(init_line("c2a9e3f1"));
        }
        lines.extend(speech_lines(&parts));

        let (line_events, end_events) =
            read_then_end(AgentKind::GeminiCli, &lines);

        let speech_events: Vec<&AgentEvent> = line_events
            .iter()
            .filter(|agent_event| matches!(agent_event, AgentEvent::Said(_)))
            .collect();
        prop_assert!(speech_events.is_empty());
        prop_assert_eq!(end_events, said_speech(&parts));
    }

    #[test]
    fn test_read_end_of_output_property_said_speech_is_not_repeated(
        parts in any_speech_parts(),
        ending_line in any_speech_ending_line(),
    ) {
        let mut lines = speech_lines(&parts);
        lines.push(ending_line);

        let (line_events, end_events) =
            read_then_end(AgentKind::GeminiCli, &lines);

        let expected_speech = said_speech(&parts);
        prop_assert_eq!(line_events.first(), expected_speech.first());
        prop_assert_eq!(end_events, Vec::new());
    }

    #[test]
    fn test_read_end_of_output_property_other_agents_hold_nothing(
        agent in any_other_agent(),
        lines in vec(any::<String>(), 0..LARGEST_LINE_COUNT),
    ) {
        let (_line_events, end_events) = read_then_end(agent, &lines);

        prop_assert_eq!(end_events, Vec::new());
    }

    #[test]
    fn test_describe_unfinished_speech_property_blank_speech_says_nothing(
        spaces in vec(prop_oneof![Just(" "), Just("\t"), Just("\n")], 1..6),
    ) {
        let parts: Vec<String> =
            spaces.iter().map(|space| (*space).to_owned()).collect();
        let mut finished_lines = speech_lines(&parts);
        finished_lines.push(finished_line());

        let (_line_events, end_events) =
            read_then_end(AgentKind::GeminiCli, &speech_lines(&parts));
        let finished = read_gemini(&finished_lines);

        prop_assert_eq!(end_events, Vec::new());
        prop_assert_eq!(finished, vec![AgentEvent::Finished]);
    }

    #[test]
    fn test_describe_unfinished_speech_property_said_text_is_trimmed(
        leading in "[ \t]{0,3}",
        parts in any_speech_parts(),
        trailing in "[ \t\n]{0,3}",
    ) {
        let mut padded_parts = vec![leading];
        padded_parts.extend(parts.iter().cloned());
        padded_parts.push(trailing);

        let (_line_events, end_events) =
            read_then_end(AgentKind::GeminiCli, &speech_lines(&padded_parts));

        prop_assert_eq!(end_events, said_speech(&parts));
    }

    #[test]
    fn test_describe_unfinished_speech_property_end_and_finish_agree(
        parts in any_speech_parts(),
    ) {
        let (_line_events, end_events) =
            read_then_end(AgentKind::GeminiCli, &speech_lines(&parts));
        let mut finished_lines = speech_lines(&parts);
        finished_lines.push(finished_line());

        let finished_events = read_gemini(&finished_lines);

        let mut expected_finish = end_events;
        expected_finish.push(AgentEvent::Finished);
        prop_assert_eq!(finished_events, expected_finish);
    }
}

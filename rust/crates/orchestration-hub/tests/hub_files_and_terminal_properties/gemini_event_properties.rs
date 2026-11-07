use std::slice::from_ref;

use orchestration_hub::agent_event::AgentEvent;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::json;

use crate::gemini_lines::{
    any_gemini_line, error_event_line, finished_line, init_line, speech_lines,
    tool_result_line, tool_use_line,
};
use crate::gemini_reading::{any_speech_parts, read_gemini, said_speech};

const KNOWN_EVENT_TYPES: [&str; 6] = [
    "init",
    "message",
    "tool_use",
    "tool_result",
    "error",
    "result",
];
const LARGEST_LINE_COUNT: usize = 6;

const PRINTED_SPACES: [char; 5] =
    [' ', '\t', '\u{A0}', '\u{2003}', '\u{3000}'];

fn any_blank_text() -> impl Strategy<Value = String> {
    let space = proptest::sample::select(PRINTED_SPACES.to_vec());
    vec(space, 0..4).prop_map(|spaces| spaces.into_iter().collect())
}

fn any_padded_text() -> impl Strategy<Value = String> {
    (
        any_blank_text(),
        "[a-zA-Z0-9][a-zA-Z0-9 .:]{0,20}",
        any_blank_text(),
    )
        .prop_map(|(leading, words, trailing)| {
            format!("{leading}{words}{trailing}")
        })
}

fn any_ending_line() -> impl Strategy<Value = String> {
    prop_oneof![
        "[a-f0-9-]{1,36}".prop_map(|session| init_line(&session)),
        "[a-z ]{1,20}".prop_map(|command| {
            tool_use_line("run_shell_command", &json!({"command": command}))
        }),
        any_padded_text().prop_map(|message| {
            tool_result_line("error", None, Some(&message))
        }),
        any_padded_text()
            .prop_map(|message| { error_event_line("warning", &message) }),
        Just(finished_line()),
    ]
}

fn any_unknown_event_line() -> impl Strategy<Value = String> {
    ("[a-z_]{1,12}", any::<String>())
        .prop_filter("the type is unknown", |(event_type, _text)| {
            !KNOWN_EVENT_TYPES.contains(&event_type.as_str())
        })
        .prop_map(|(event_type, text)| {
            json!({"type": event_type, "content": text}).to_string()
        })
}

fn with_lines(mut lines: Vec<String>, later_lines: &[String]) -> Vec<String> {
    lines.extend_from_slice(later_lines);
    lines
}

proptest! {
    #[test]
    fn test_parse_gemini_line_property_ended_speech_comes_first(
        parts in any_speech_parts(),
        ending_line in any_ending_line(),
    ) {
        let lines = with_lines(speech_lines(&parts), from_ref(&ending_line));

        let agent_events = read_gemini(&lines);

        let mut expected = said_speech(&parts);
        expected.extend(read_gemini(&[ending_line]));
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_parse_gemini_line_property_unknown_types_keep_speech_whole(
        parts in any_speech_parts(),
        unknown_lines in vec(any_unknown_event_line(), 1..LARGEST_LINE_COUNT),
    ) {
        let mut lines = Vec::new();
        for (part, unknown_line) in parts.iter().zip(&unknown_lines) {
            lines.extend(speech_lines(from_ref(part)));
            lines.push(unknown_line.clone());
        }
        let spoken_count = parts.len().min(unknown_lines.len());
        lines.push(finished_line());

        let agent_events = read_gemini(&lines);

        let mut expected = said_speech(&parts[..spoken_count]);
        expected.push(AgentEvent::Finished);
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_parse_gemini_line_property_runs_split_after_an_end_read_alike(
        first_lines in vec(any_gemini_line(), 0..LARGEST_LINE_COUNT),
        second_lines in vec(any_gemini_line(), 0..LARGEST_LINE_COUNT),
    ) {
        let first_run = with_lines(first_lines, &[finished_line()]);
        let whole_run = with_lines(first_run.clone(), &second_lines);

        let whole_events = read_gemini(&whole_run);

        let mut expected = read_gemini(&first_run);
        expected.extend(read_gemini(&second_lines));
        prop_assert_eq!(whole_events, expected);
    }

    #[test]
    fn test_start_session_property_keeps_the_session_as_given(
        session in any_padded_text(),
    ) {
        let agent_events = read_gemini(&[init_line(&session)]);

        prop_assert_eq!(
            agent_events,
            vec![AgentEvent::SessionStarted(session)],
        );
    }

    #[test]
    fn test_start_session_property_blank_sessions_still_end_the_speech(
        parts in any_speech_parts(),
        session in any_blank_text(),
    ) {
        let lines = with_lines(speech_lines(&parts), &[init_line(&session)]);

        let agent_events = read_gemini(&lines);

        prop_assert_eq!(agent_events, said_speech(&parts));
    }

    #[test]
    fn test_start_session_property_each_init_names_its_session(
        sessions in vec("[a-f0-9]{8}", 1..LARGEST_LINE_COUNT),
    ) {
        let lines: Vec<String> =
            sessions.iter().map(|session| init_line(session)).collect();

        let agent_events = read_gemini(&lines);

        let expected: Vec<AgentEvent> = sessions
            .into_iter()
            .map(AgentEvent::SessionStarted)
            .collect();
        prop_assert_eq!(agent_events, expected);
    }
}

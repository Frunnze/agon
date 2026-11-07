use std::path::Path;

use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_output::AgentOutputReader;
use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::json;

use crate::gemini_lines::{finished_line, message_line, speech_lines};
use crate::gemini_reading::read_gemini;

const TERMINAL_CODES: [&str; 5] = [
    "\u{1b}[31m",
    "\u{1b}[0m",
    "\u{1b}[1;32m",
    "\u{1b}[2K",
    "\u{1b}[?25l",
];
const LARGEST_CUT_COUNT: usize = 5;

fn any_plain_words() -> impl Strategy<Value = String> {
    "[a-zA-Z][a-zA-Z0-9 ,.]{0,20}[a-zA-Z0-9.]"
}

fn any_coloured_speech() -> impl Strategy<Value = (String, String)> {
    (
        any_plain_words(),
        vec(
            (
                any::<usize>(),
                proptest::sample::select(TERMINAL_CODES.to_vec()),
            ),
            1..4,
        ),
    )
        .prop_map(|(plain, insertions)| {
            let mut characters: Vec<String> =
                plain.chars().map(String::from).collect();
            for (position, code) in insertions {
                let index = position % (characters.len() + 1);
                characters.insert(index, code.to_owned());
            }
            (characters.concat(), plain)
        })
}

fn split_at_characters(text: &str, cut_points: &[usize]) -> Vec<String> {
    let characters: Vec<char> = text.chars().collect();
    let mut cuts: Vec<usize> = cut_points
        .iter()
        .map(|cut| cut % (characters.len() + 1))
        .collect();
    cuts.sort_unstable();
    let mut parts = Vec::new();
    let mut start = 0;
    for cut in cuts {
        parts.push(characters[start..cut].iter().collect());
        start = cut;
    }
    parts.push(characters[start..].iter().collect());
    parts
}

fn read_until_the_end(lines: &[String]) -> Vec<AgentEvent> {
    let task_folder = Path::new(CONTAINER_WORKSPACE_DIRECTORY);
    let mut reader = AgentOutputReader::new(AgentKind::GeminiCli, task_folder);
    let mut agent_events = Vec::new();
    for line in lines {
        let (next_reader, line_events) = reader.read_line(line);
        reader = next_reader;
        agent_events.extend(line_events);
    }
    agent_events.extend(reader.read_end_of_output());
    agent_events
}

fn said(text: &str) -> Vec<AgentEvent> {
    vec![AgentEvent::Said(text.trim().to_owned())]
}

proptest! {
    #[test]
    fn test_describe_unfinished_speech_property_split_codes_leave_nothing(
        (coloured, plain) in any_coloured_speech(),
        cut_points in vec(any::<usize>(), 0..LARGEST_CUT_COUNT),
    ) {
        let parts = split_at_characters(&coloured, &cut_points);
        let mut lines = speech_lines(&parts);
        lines.push(finished_line());

        let agent_events = read_gemini(&lines);

        let mut expected = said(&plain);
        expected.push(AgentEvent::Finished);
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_describe_unfinished_speech_property_cut_last_codes_are_dropped(
        plain in any_plain_words(),
        code in proptest::sample::select(TERMINAL_CODES.to_vec()),
        kept_length in 1_usize..3,
    ) {
        let cut_code: String = code.chars().take(kept_length).collect();
        let parts = vec![plain.clone(), cut_code];

        let agent_events = read_until_the_end(&speech_lines(&parts));

        prop_assert_eq!(agent_events, said(&plain));
    }

    #[test]
    fn test_describe_unfinished_speech_property_codes_go_at_end_and_finish(
        (coloured, _plain) in any_coloured_speech(),
        cut_points in vec(any::<usize>(), 0..LARGEST_CUT_COUNT),
    ) {
        let parts = split_at_characters(&coloured, &cut_points);
        let mut finished_lines = speech_lines(&parts);
        finished_lines.push(finished_line());

        let ended = read_until_the_end(&speech_lines(&parts));
        let finished = read_gemini(&finished_lines);

        let mut expected = ended;
        expected.push(AgentEvent::Finished);
        prop_assert_eq!(finished, expected);
    }

    #[test]
    fn test_read_speech_part_property_user_messages_are_never_speech(
        (coloured, _plain) in any_coloured_speech(),
    ) {
        let lines = vec![message_line("user", &coloured), finished_line()];

        prop_assert_eq!(read_gemini(&lines), vec![AgentEvent::Finished]);
    }

    #[test]
    fn test_read_speech_part_property_odd_content_is_never_speech(
        content in prop_oneof![
            any::<i64>().prop_map(|number| json!(number)),
            any::<bool>().prop_map(|flag| json!(flag)),
            Just(json!(null)),
            Just(json!(["a", "b"])),
        ],
        plain in any_plain_words(),
    ) {
        let odd_line = json!({
            "type": "message",
            "role": "assistant",
            "content": content,
        })
        .to_string();
        let lines = vec![
            message_line("assistant", &plain),
            odd_line,
            finished_line(),
        ];

        let mut expected = said(&plain);
        expected.push(AgentEvent::Finished);
        prop_assert_eq!(read_gemini(&lines), expected);
    }

    #[test]
    fn test_read_speech_part_property_codes_in_tool_lines_stay_stripped(
        (coloured, plain) in any_coloured_speech(),
    ) {
        let line = json!({
            "type": "tool_use",
            "tool_name": "run_shell_command",
            "parameters": {"command": coloured},
        })
        .to_string();

        let agent_events = read_gemini(&[line]);

        let expected = AgentEvent::UsedTool(format!("Ran {}", plain.trim()));
        prop_assert_eq!(agent_events, vec![expected]);
    }
}

use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::json;

use crate::gemini_lines::{
    finished_line, message_line, speech_lines, tool_use_line,
};
use crate::log_support::UNICODE_SPACES;
use crate::stream_support::{any_tool_detail, read_container_events};

const ASSISTANT_ROLE: &str = "assistant";
const USER_ROLE: &str = "user";
const LARGEST_PART_COUNT: usize = 6;
const UNREAD_GEMINI_LINES: [&str; 4] = [
    r#"{"type":"stats","total_tokens":5}"#,
    r#"{"type":"message","role":"assistant","content":5}"#,
    r#"{"type":"init","session_id":null}"#,
    "[1,2,3]",
];

fn read_gemini(lines: &[String]) -> Vec<AgentEvent> {
    read_container_events(AgentKind::GeminiCli, lines)
}

fn with_finish(mut lines: Vec<String>) -> Vec<String> {
    lines.push(finished_line());
    lines
}

fn split_at_characters(text: &str, cut_points: &[usize]) -> Vec<String> {
    let characters: Vec<char> = text.chars().collect();
    let mut sorted_cuts: Vec<usize> = cut_points
        .iter()
        .map(|cut| cut % (characters.len() + 1))
        .collect();
    sorted_cuts.sort_unstable();

    let mut parts = Vec::new();
    let mut start = 0;
    for cut in sorted_cuts {
        parts.push(characters[start..cut].iter().collect());
        start = cut;
    }
    parts.push(characters[start..].iter().collect());
    parts
}

fn speech_of(parts: &[String]) -> Vec<AgentEvent> {
    let speech = parts.concat();
    let spoken = speech.trim();
    if spoken.is_empty() {
        return Vec::new();
    }
    vec![AgentEvent::Said(spoken.to_owned())]
}

fn any_speech_part() -> impl Strategy<Value = String> {
    "\\PC{0,24}"
}

fn any_spoken_text() -> impl Strategy<Value = String> {
    any_speech_part()
        .prop_filter("speech has text", |text| !text.trim().is_empty())
}

fn any_blank_part() -> impl Strategy<Value = String> {
    let space = proptest::sample::select(UNICODE_SPACES.to_vec());
    vec(space, 0..4).prop_map(|spaces| spaces.into_iter().collect())
}

proptest! {
    #[test]
    fn test_read_gemini_line_property_chunk_boundaries_never_matter(
        text in any_spoken_text(),
        cut_points in vec(any::<usize>(), 0..LARGEST_PART_COUNT),
    ) {
        let parts = split_at_characters(&text, &cut_points);

        let chunked = read_gemini(&with_finish(speech_lines(&parts)));
        let whole_part = std::slice::from_ref(&text);
        let whole = read_gemini(&with_finish(speech_lines(whole_part)));

        let expected = vec![
            AgentEvent::Said(text.trim().to_owned()),
            AgentEvent::Finished,
        ];
        prop_assert_eq!(&chunked, &expected);
        prop_assert_eq!(whole, expected);
    }

    #[test]
    fn test_read_gemini_line_property_user_messages_never_join_speech(
        pieces in vec(
            (any::<bool>(), any_speech_part()),
            1..LARGEST_PART_COUNT,
        ),
    ) {
        let mut lines = Vec::new();
        let mut assistant_parts = Vec::new();
        for (is_assistant, content) in &pieces {
            let role = if *is_assistant { ASSISTANT_ROLE } else { USER_ROLE };
            lines.push(message_line(role, content));
            if *is_assistant {
                assistant_parts.push(content.clone());
            }
        }

        let agent_events = read_gemini(&with_finish(lines));

        let mut expected = speech_of(&assistant_parts);
        expected.push(AgentEvent::Finished);
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_read_gemini_line_property_unread_json_keeps_speech_whole(
        parts in vec(any_speech_part(), 1..LARGEST_PART_COUNT),
        unread_picks in vec(0..UNREAD_GEMINI_LINES.len(), LARGEST_PART_COUNT),
    ) {
        let mut lines = Vec::new();
        for (part, unread_pick) in parts.iter().zip(&unread_picks) {
            lines.push(message_line(ASSISTANT_ROLE, part));
            lines.push(UNREAD_GEMINI_LINES[*unread_pick].to_owned());
        }

        let agent_events = read_gemini(&with_finish(lines));

        let mut expected = speech_of(&parts);
        expected.push(AgentEvent::Finished);
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_finish_speech_before_property_speech_comes_before_the_event(
        parts in vec(any_spoken_text(), 1..LARGEST_PART_COUNT),
        command in any_tool_detail(),
    ) {
        let mut lines = speech_lines(&parts);
        let parameters = json!({"command": command});
        lines.push(tool_use_line("run_shell_command", &parameters));

        let agent_events = read_gemini(&lines);

        let mut expected = speech_of(&parts);
        expected.push(AgentEvent::UsedTool(format!("Ran {command}")));
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_finish_speech_before_property_blank_speech_gives_no_said(
        parts in vec(any_blank_part(), 1..LARGEST_PART_COUNT),
    ) {
        let agent_events = read_gemini(&with_finish(speech_lines(&parts)));

        prop_assert_eq!(agent_events, vec![AgentEvent::Finished]);
    }

    #[test]
    fn test_finish_speech_before_property_speech_is_said_only_once(
        parts in vec(any_spoken_text(), 1..LARGEST_PART_COUNT),
        later_finishes in 1_usize..4,
    ) {
        let mut lines = with_finish(speech_lines(&parts));
        for _ in 0..later_finishes {
            lines.push(finished_line());
        }

        let agent_events = read_gemini(&lines);

        let mut expected = speech_of(&parts);
        for _ in 0..=later_finishes {
            expected.push(AgentEvent::Finished);
        }
        prop_assert_eq!(agent_events, expected);
    }
}

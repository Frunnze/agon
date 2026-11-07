use orchestration_hub::agent_event::AgentEvent;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::json_texts::join_words;
use crate::log_support::{
    MAXIMUM_LOG_TEXT_CHARACTERS, SAID_PREFIX, SESSION_PREFIX,
    SHORTENED_MARKER, UNICODE_SPACES, any_agent_events, any_event_text,
    any_white_space_run, describe_events,
};

const SHORTENED_TEXT_CHARACTERS: usize = MAXIMUM_LOG_TEXT_CHARACTERS + 1;
const ESCAPE: char = '\u{1b}';
const PRETTY_ITEM: &str = "{\n  \"title\": \"Ship it\",\n  \"steps\": []\n}";

type TextEvent = fn(String) -> AgentEvent;

const TEXT_EVENTS: [TextEvent; 4] = [
    AgentEvent::Said,
    AgentEvent::ToolFailed,
    AgentEvent::Failed,
    AgentEvent::SessionStarted,
];

fn any_text_event() -> impl Strategy<Value = TextEvent> {
    proptest::sample::select(TEXT_EVENTS.to_vec())
}

fn long_text() -> impl Strategy<Value = String> {
    vec("[a-zA-Z0-9é中😀]{1,9}", 30..60).prop_map(|words| words.join(" "))
}

fn any_blank_text() -> impl Strategy<Value = String> {
    let space = proptest::sample::select(UNICODE_SPACES.to_vec());
    vec(space, 0..6).prop_map(|spaces| spaces.into_iter().collect())
}

fn any_json_text() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(PRETTY_ITEM.to_owned()),
        any::<String>()
            .prop_map(|text| serde_json::json!({"text": text}).to_string()),
        vec(any::<i64>(), 0..4)
            .prop_map(|numbers| serde_json::json!(numbers).to_string()),
    ]
}

fn coloured(text: &str) -> String {
    format!("{ESCAPE}[1;31m{text}{ESCAPE}[0m")
}

fn strip_said_prefix(text: &str) -> String {
    text.strip_prefix(SAID_PREFIX).unwrap_or(text).to_owned()
}

proptest! {
    #[test]
    fn test_shorten_readable_text_property_long_texts_are_cut(
        text in long_text(),
    ) {
        let log_lines = describe_events(&[AgentEvent::Said(text.clone())]);

        prop_assert_eq!(log_lines.len(), 1);
        let shown = strip_said_prefix(&log_lines[0].text);
        prop_assert!(shown.chars().count() <= SHORTENED_TEXT_CHARACTERS);
        let kept = shown.strip_suffix(SHORTENED_MARKER);
        prop_assert!(kept.is_some(), "{}", shown);
        let kept = kept.unwrap_or_default();
        prop_assert!(!kept.is_empty() && join_words(&text).starts_with(kept));
    }

    #[test]
    fn test_shorten_readable_text_property_json_texts_stay_out(
        text_event in any_text_event(),
        json_text in any_json_text(),
    ) {
        let log_lines = describe_events(&[text_event(json_text)]);

        prop_assert_eq!(log_lines, Vec::new());
    }

    #[test]
    fn test_shorten_readable_text_property_blank_texts_give_no_line(
        text_event in any_text_event(),
        blank_text in any_blank_text(),
    ) {
        let log_lines = describe_events(&[text_event(blank_text)]);

        prop_assert_eq!(log_lines, Vec::new());
    }

    #[test]
    fn test_shorten_readable_text_property_terminal_codes_never_show(
        text_event in any_text_event(),
        text in "[a-zA-Z0-9 ]{1,40}",
    ) {
        prop_assume!(!text.trim().is_empty());

        let log_lines = describe_events(&[text_event(coloured(&text))]);

        prop_assert_eq!(log_lines.len(), 1);
        let shown = &log_lines[0].text;
        prop_assert!(!shown.contains(ESCAPE), "{:?}", shown);
        prop_assert!(shown.ends_with(&join_words(&text)), "{:?}", shown);
    }

    #[test]
    fn test_join_words_property_log_lines_never_break(
        agent_events in any_agent_events(),
    ) {
        for log_line in describe_events(&agent_events) {
            let has_break = log_line
                .text
                .contains(['\n', '\r', '\t', '\u{85}', '\u{2028}']);
            prop_assert!(!has_break, "{:?}", log_line.text);
        }
    }

    #[test]
    fn test_join_words_property_white_space_runs_become_one_space(
        words in vec("[a-zA-Z0-9é中]{1,6}", 1..8),
        separators in vec(any_white_space_run(), 8),
        session in "[a-f0-9]{8}",
    ) {
        let mut spoken = String::new();
        for (word, separator) in words.iter().zip(&separators) {
            spoken.push_str(separator);
            spoken.push_str(word);
        }

        let log_lines = describe_events(&[
            AgentEvent::Said(spoken),
            AgentEvent::SessionStarted(format!("{}{session}", separators[0])),
        ]);

        let said = format!("{SAID_PREFIX}{}", words.join(" "));
        let started = format!("{SESSION_PREFIX}{session}");
        let texts: Vec<String> =
            log_lines.into_iter().map(|log_line| log_line.text).collect();
        prop_assert_eq!(texts, vec![said, started]);
    }

    #[test]
    fn test_join_words_property_lines_have_no_outer_white_space(
        text_event in any_text_event(),
        text in any_event_text(),
    ) {
        for log_line in describe_events(&[text_event(text)]) {
            prop_assert_eq!(log_line.text.trim(), log_line.text.as_str());
        }
    }
}

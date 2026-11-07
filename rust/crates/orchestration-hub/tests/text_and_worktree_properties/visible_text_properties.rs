use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_log::describe_agent_event_log_lines;
use proptest::prelude::*;
use serde_json::json;

use crate::agent_reading::parse_agent_line;
use crate::claude_lines::assistant_line;
use crate::json_texts::join_words;
use crate::screen_support::{
    LOG_LINE_START, any_plain_text, any_still_sequence, show_in_log,
};
use crate::text_shapes::{any_code_placements, any_colour_code, insert_codes};

const LONGEST_LOG_TEXT: usize = 120;
const LONGEST_DETAIL: usize = 100;
const SHORTENED_MARKER: char = '…';
const SAID_PREFIX: &str = "Said: ";
const READ_PREFIX: &str = "Read ";
const KEPT_CONTROLS: [char; 4] = ['\t', '\n', '\r', '\u{8}'];

fn any_said_text() -> impl Strategy<Value = String> {
    "[a-zé中 ]{0,300}"
}

fn any_outside_path() -> impl Strategy<Value = String> {
    "[a-zé中_-]{1,4}(/[a-zé中 ._-]{0,30}){0,10}/[a-zé中_-]{1,6}"
        .prop_map(|path| format!("/data/{path}"))
}

fn show_said(text: &str) -> Option<String> {
    let said = [AgentEvent::Said(text.to_owned())];
    let log_lines = describe_agent_event_log_lines(&said);
    let first = log_lines.first()?;
    first.text.strip_prefix(SAID_PREFIX).map(str::to_owned)
}

fn describe_read(path: &str) -> Option<String> {
    let tool_use = json!({
        "type": "tool_use",
        "name": "Read",
        "input": {"file_path": path},
    });
    let line = assistant_line(&json!([tool_use]));
    let agent_events = parse_agent_line(AgentKind::ClaudeCode, &line);
    let Some(AgentEvent::UsedTool(description)) = agent_events.first() else {
        return None;
    };
    description.strip_prefix(READ_PREFIX).map(str::to_owned)
}

fn is_in_order_within(shown: &str, original: &str) -> bool {
    let mut remaining = original.chars();
    shown
        .chars()
        .all(|character| remaining.any(|other| other == character))
}

proptest! {
    #[test]
    fn test_strip_terminal_control_sequences_property_codes_leave_bare_text(
        text in any_plain_text(),
        placements in any_code_placements(
            prop_oneof![any_still_sequence(), any_colour_code()]
        ),
    ) {
        let noisy = insert_codes(&text, &placements);

        let expected = format!("{LOG_LINE_START}{text}").trim_end().to_owned();
        prop_assert_eq!(show_in_log(&noisy), expected);
    }

    #[test]
    fn test_strip_terminal_control_sequences_property_is_idempotent(
        output in any::<String>(),
    ) {
        let once = show_in_log(&output);
        let once_without_start =
            once.strip_prefix(LOG_LINE_START).unwrap_or_default();

        prop_assert_eq!(show_in_log(once_without_start), once);
    }

    #[test]
    fn test_strip_terminal_control_sequences_property_keeps_only_text(
        output in any::<String>(),
    ) {
        let shown = show_in_log(&output);
        let shown_without_start =
            shown.strip_prefix(LOG_LINE_START).unwrap_or_default();

        prop_assert!(is_in_order_within(shown_without_start, &output));
        let has_hidden_control = shown.chars().any(|character| {
            character.is_control() && !KEPT_CONTROLS.contains(&character)
        });
        prop_assert!(!has_hidden_control, "{:?}", shown);
    }

    #[test]
    fn test_shorten_to_characters_property_keeps_at_most_the_limit(
        text in any_said_text(),
    ) {
        let Some(shown) = show_said(&text) else {
            prop_assert!(join_words(&text).is_empty());
            return Ok(());
        };

        let kept = shown.strip_suffix(SHORTENED_MARKER).unwrap_or(&shown);
        prop_assert!(kept.chars().count() <= LONGEST_LOG_TEXT);
        prop_assert!(!kept.contains(SHORTENED_MARKER));
    }

    #[test]
    fn test_shorten_to_characters_property_short_text_is_unchanged(
        text in "[a-zé中 ]{1,120}",
    ) {
        let joined = join_words(&text);
        prop_assume!(!joined.is_empty());

        prop_assert_eq!(show_said(&text), Some(joined));
    }

    #[test]
    fn test_shorten_to_characters_property_long_text_keeps_its_start(
        text in "[a-zé中 ]{121,300}",
    ) {
        let joined = join_words(&text);
        prop_assume!(joined.chars().count() > LONGEST_LOG_TEXT);

        let shown = show_said(&text).unwrap_or_default();

        let kept = shown.strip_suffix(SHORTENED_MARKER).unwrap_or_default();
        prop_assert!(!kept.is_empty());
        prop_assert!(joined.starts_with(kept), "{:?}", shown);
        prop_assert_eq!(kept.trim_end(), kept);
    }

    #[test]
    fn test_shorten_keeping_the_end_property_keeps_at_most_the_limit(
        path in any_outside_path(),
    ) {
        let shown = describe_read(&path).unwrap_or_default();

        let kept = shown.strip_prefix(SHORTENED_MARKER).unwrap_or(&shown);
        prop_assert!(!kept.is_empty());
        prop_assert!(kept.chars().count() <= LONGEST_DETAIL, "{:?}", shown);
    }

    #[test]
    fn test_shorten_keeping_the_end_property_short_paths_are_unchanged(
        path in "/[a-z]{1,8}(/[a-zé中._-]{1,10}){0,7}",
    ) {
        prop_assume!(path.chars().count() <= LONGEST_DETAIL);

        prop_assert_eq!(describe_read(&path), Some(path));
    }

    #[test]
    fn test_shorten_keeping_the_end_property_long_paths_keep_their_end(
        path in any_outside_path(),
    ) {
        prop_assume!(path.chars().count() > LONGEST_DETAIL);

        let shown = describe_read(&path).unwrap_or_default();

        let kept = shown.strip_prefix(SHORTENED_MARKER).unwrap_or_default();
        prop_assert!(!kept.is_empty());
        prop_assert!(path.ends_with(kept), "{:?}", shown);
        prop_assert_eq!(kept.trim_start(), kept);
    }
}

use orchestration_core::approval::ApprovalAction;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_log::{AgentLogLine, describe_agent_log_lines};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::json_texts::{join_words, reads_as_json};

pub const JSON_LINE: &str = r#"{"type":"assistant"}"#;
pub const SAID_PREFIX: &str = "Said: ";
pub const FAILED_PREFIX: &str = "Failed: ";
pub const SESSION_PREFIX: &str = "Agent started, session ";
pub const MAXIMUM_LOG_TEXT_CHARACTERS: usize = 120;
pub const SHORTENED_MARKER: char = '…';
pub const UNICODE_SPACES: [char; 9] = [
    ' ', '\t', '\n', '\r', '\u{A0}', '\u{2003}', '\u{3000}', '\u{2028}',
    '\u{85}',
];
const WORD_SEPARATING_SPACES: [char; 7] =
    [' ', '\t', '\n', '\r', '\u{A0}', '\u{2003}', '\u{3000}'];
const KEPT_CONTROL_CHARACTERS: [char; 3] = ['\t', '\n', '\r'];
const LARGEST_EVENT_COUNT: usize = 6;

pub fn any_white_space_run() -> impl Strategy<Value = String> {
    let space = proptest::sample::select(WORD_SEPARATING_SPACES.to_vec());
    vec(space, 1..4).prop_map(|spaces| spaces.into_iter().collect())
}

pub fn any_event_text() -> impl Strategy<Value = String> {
    let word = "[a-zA-Z0-9é中😀.,:!?()-]{1,12}";
    let spaced_words =
        vec((any_white_space_run(), word), 0..30).prop_map(|pieces| {
            let mut text = String::new();
            for (spaces, word) in pieces {
                text.push_str(&spaces);
                text.push_str(&word);
            }
            text
        });
    prop_oneof![
        any::<String>().prop_map(|text| keep_printed_characters(&text)),
        spaced_words,
        Just("{\n  \"title\": \"a drafted item\"\n}".to_owned()),
        Just("[1, 2, 3]".to_owned()),
    ]
}

pub fn any_approval_action() -> impl Strategy<Value = ApprovalAction> {
    ("[a-z]{1,8}", any::<String>()).prop_map(|(tool, command)| {
        ApprovalAction::RunCommand {
            tool,
            summary: command.clone(),
            command,
        }
    })
}

pub fn any_agent_event() -> impl Strategy<Value = AgentEvent> {
    prop_oneof![
        any_event_text().prop_map(AgentEvent::Said),
        "[A-Z][a-z]{1,6} [a-z/.]{1,20}".prop_map(AgentEvent::UsedTool),
        any_event_text().prop_map(AgentEvent::ToolFailed),
        Just(AgentEvent::Finished),
        any_event_text().prop_map(AgentEvent::Failed),
        any_event_text().prop_map(AgentEvent::SessionStarted),
        any_approval_action().prop_map(AgentEvent::AskedForApproval),
    ]
}

pub fn any_agent_events() -> impl Strategy<Value = Vec<AgentEvent>> {
    vec(any_agent_event(), 0..=LARGEST_EVENT_COUNT)
}

pub fn describe_events(agent_events: &[AgentEvent]) -> Vec<AgentLogLine> {
    describe_agent_log_lines(JSON_LINE, agent_events)
}

fn is_printed_character(character: char) -> bool {
    !character.is_control() || KEPT_CONTROL_CHARACTERS.contains(&character)
}

fn keep_printed_characters(text: &str) -> String {
    text.chars()
        .filter(|character| is_printed_character(*character))
        .collect()
}

pub fn has_only_kept_controls(text: &str) -> bool {
    text.chars().all(is_printed_character)
}

pub fn is_readable(text: &str) -> bool {
    !join_words(text).is_empty() && !reads_as_json(text)
}

pub fn is_failure(agent_event: &AgentEvent) -> bool {
    matches!(
        agent_event,
        AgentEvent::ToolFailed(_) | AgentEvent::Failed(_)
    )
}

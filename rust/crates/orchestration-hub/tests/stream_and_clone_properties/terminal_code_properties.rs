use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;

use crate::command_support::ALL_AGENTS;
use crate::stream_support::read_container_events;
use crate::text_shapes::{
    any_code_placements, any_colour_code, any_text_shape, insert_codes,
};

const KEPT_CONTROLS: [char; 4] = ['\t', '\n', '\r', '\u{8}'];
const BROKEN_CODES: [&str; 8] = [
    "\u{1b}",
    "\u{1b}[",
    "\u{1b}[31",
    "\u{1b}]8;;",
    "\u{1b}]0;title\u{1b}",
    "\u{7}",
    "\u{0}",
    "\u{9b}",
];

fn any_hostile_code() -> impl Strategy<Value = String> {
    let broken_code = proptest::sample::select(BROKEN_CODES.to_vec());
    prop_oneof![any_colour_code(), broken_code.prop_map(String::from)]
}

fn any_json_scalar_line() -> impl Strategy<Value = String> {
    prop_oneof![
        "-?[0-9]{1,6}(\\.[0-9]{1,4})?([eE][+-]?[0-9]{1,2})?",
        "\"[a-zé ]{0,8}(\\\\u00e9|\\\\n|\\\\u001b\\[31m)?[a-z]{0,4}\"",
        Just("true".to_owned()),
        Just("null".to_owned()),
    ]
}

fn read_event_text(agent_event: &AgentEvent) -> Option<&str> {
    match agent_event {
        AgentEvent::Said(text)
        | AgentEvent::UsedTool(text)
        | AgentEvent::ToolFailed(text)
        | AgentEvent::Failed(text)
        | AgentEvent::SessionStarted(text) => Some(text),
        AgentEvent::Finished | AgentEvent::AskedForApproval(_) => None,
    }
}

fn has_terminal_control(text: &str) -> bool {
    text.chars().any(|character| {
        character.is_control() && !KEPT_CONTROLS.contains(&character)
    })
}

proptest! {
    #[test]
    fn test_strip_terminal_codes_in_json_property_coloured_reads_as_bare(
        (agent, text_lines) in any_text_shape(),
        text in any::<String>(),
        placements in any_code_placements(any_colour_code()),
    ) {
        let coloured_text = insert_codes(&text, &placements);

        let bare_events = read_container_events(agent, &text_lines(&text));
        let coloured_lines = text_lines(&coloured_text);
        let coloured_events = read_container_events(agent, &coloured_lines);

        prop_assert_eq!(coloured_events, bare_events);
    }

    #[test]
    fn test_strip_terminal_codes_in_json_property_no_control_reaches_chat(
        (agent, text_lines) in any_text_shape(),
        text in any::<String>(),
        placements in any_code_placements(any_hostile_code()),
    ) {
        let hostile_text = insert_codes(&text, &placements);

        let agent_events =
            read_container_events(agent, &text_lines(&hostile_text));

        for agent_event in &agent_events {
            let event_text = read_event_text(agent_event).unwrap_or_default();
            prop_assert!(
                !has_terminal_control(event_text),
                "{:?}",
                agent_event,
            );
        }
    }

    #[test]
    fn test_strip_terminal_codes_in_json_property_scalars_keep_spelling(
        line in any_json_scalar_line(),
    ) {
        let lines = vec![line.clone()];

        for agent in ALL_AGENTS {
            let agent_events = read_container_events(agent, &lines);
            let expected = vec![AgentEvent::Said(line.clone())];
            prop_assert_eq!(agent_events, expected, "{:?}", agent);
        }
    }
}

mod agent_reading;

use agent_reading::parse_agent_line;
use orchestration_core::workflow::AgentKind;
use proptest::prelude::*;

const SHOW_CURSOR: &str = "\u{1b}[?25h";

fn any_agent() -> impl Strategy<Value = AgentKind> {
    prop_oneof![
        Just(AgentKind::ClaudeCode),
        Just(AgentKind::Codex),
        Just(AgentKind::GeminiCli),
    ]
}

fn any_control_sequence() -> impl Strategy<Value = String> {
    prop_oneof![
        "\u{1b}\\[[0-9;?]{0,6}[A-Za-z]",
        "\u{1b}\\][a-z0-9;]{0,10}\u{7}",
    ]
}

fn any_control_sequences() -> impl Strategy<Value = String> {
    prop::collection::vec(any_control_sequence(), 1..4)
        .prop_map(|sequences| sequences.concat())
}

fn any_plain_text() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9 .,:!?]{1,40}"
        .prop_filter("text has content", |text| !text.trim().is_empty())
}

proptest! {
    #[test]
    fn test_parse_agent_line_property_control_codes_alone_give_no_events(
        agent in any_agent(),
        sequences in any_control_sequences(),
    ) {
        prop_assert!(parse_agent_line(agent, &sequences).is_empty());
    }

    #[test]
    fn test_parse_agent_line_property_control_codes_leave_text_unchanged(
        agent in any_agent(),
        text in any_plain_text(),
        before in any_control_sequences(),
        after in any_control_sequences(),
    ) {
        let decorated = format!("{before}{text}{after}");

        let decorated_events = parse_agent_line(agent, &decorated);
        let plain_events = parse_agent_line(agent, &text);

        prop_assert_eq!(decorated_events, plain_events);
    }
}

#[test]
fn the_cursor_code_claude_prints_on_exit_is_not_a_message() {
    let events = parse_agent_line(AgentKind::ClaudeCode, SHOW_CURSOR);

    assert!(events.is_empty(), "{events:?}");
}

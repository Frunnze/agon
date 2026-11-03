mod agent_reading;

use agent_reading::parse_agent_line;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;

const CLAUDE_STREAM: &str = include_str!("fixtures/claude_stream.jsonl");

const SESSION: &str = "5f0c3e2a-9b1d-4c7e-8a6f-2d4b1e9c7a30";

const BUILD_FAILURE: &str = concat!(
    "** BUILD FAILED **\n\n",
    "error: Signing for \"App\" requires a development team.",
);

const FAILED_RESULT_LINE: &str = concat!(
    r#"{"type":"result","subtype":"error_max_turns","is_error":true,"#,
    r#""duration_ms":91234,"num_turns":30,"#,
    r#""session_id":"5f0c3e2a-9b1d-4c7e-8a6f-2d4b1e9c7a30","#,
    r#""total_cost_usd":0.41,"permission_denials":[]}"#,
);

#[test]
fn parses_a_realistic_claude_stream_into_events() {
    let mut events = Vec::new();
    for line in CLAUDE_STREAM.lines() {
        events.extend(parse_agent_line(AgentKind::ClaudeCode, line));
    }

    let expected = vec![
        AgentEvent::SessionStarted(SESSION.to_string()),
        AgentEvent::Said("I'll build the app first to see the error.".into()),
        AgentEvent::UsedTool("Ran xcodebuild -scheme App".into()),
        AgentEvent::ToolFailed(BUILD_FAILURE.into()),
        AgentEvent::UsedTool(
            "Edited ios/App.xcodeproj/project.pbxproj".into(),
        ),
        AgentEvent::Said(
            "The signing team is set and the build passes now.".into(),
        ),
        AgentEvent::Finished,
    ];
    assert_eq!(events, expected);
}

#[test]
fn reports_a_failed_result_by_its_subtype() {
    let events = parse_agent_line(AgentKind::ClaudeCode, FAILED_RESULT_LINE);

    assert_eq!(events, vec![AgentEvent::Failed("error_max_turns".into())]);
}

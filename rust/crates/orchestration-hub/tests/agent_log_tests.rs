mod agent_log_lines;
mod claude_lines;
mod claude_tool_results;

use agent_log_lines::{
    Ending, any_agent, any_stream_json_line, any_unparsed_agent,
    describe_claude_log, describe_log, error_line, has_content, init_line,
    is_shortened_from, normal_line, reads_as_json, result_line, said_line,
};
use claude_lines::{any_detail, assistant_line};
use claude_tool_results::{
    ToolOutcome, any_tool_result_content, read_tool_result_text,
    tool_result_line,
};
use proptest::prelude::*;
use serde_json::{Value, json};

const CLAUDE_STREAM: &str = include_str!("fixtures/claude_stream.jsonl");
const SAID_PREFIX: &str = "Said: ";
const FAILED_PREFIX: &str = "Failed: ";
const SESSION_PREFIX: &str = "Agent started, session ";
const FINISHED_TEXT: &str = "Finished";
const UNKNOWN_TOOL_FAILURE: &str = "the tool failed";

#[test]
fn describes_a_realistic_claude_stream_as_readable_lines() {
    let mut log_lines = Vec::new();
    for line in CLAUDE_STREAM.lines() {
        log_lines.extend(describe_claude_log(line));
    }

    let expected = vec![
        normal_line(
            "Agent started, session 5f0c3e2a-9b1d-4c7e-8a6f-2d4b1e9c7a30",
        ),
        normal_line("Said: I'll build the app first to see the error."),
        normal_line("Ran xcodebuild -scheme App"),
        error_line(
            "** BUILD FAILED ** error: Signing for \"App\" requires a \
             development team.",
        ),
        normal_line("Edited ios/App.xcodeproj/project.pbxproj"),
        normal_line("Said: The signing team is set and the build passes now."),
        normal_line(FINISHED_TEXT),
    ];
    assert_eq!(log_lines, expected);
}

proptest! {
    #[test]
    fn test_describe_agent_log_lines_property_stream_json_never_shows_raw(
        line in any_stream_json_line(),
    ) {
        for log_line in describe_claude_log(&line) {
            prop_assert!(!reads_as_json(&log_line.text));
            prop_assert!(!log_line.text.contains(line.as_str()));
            prop_assert!(!log_line.text.contains('\n'));
        }
    }

    #[test]
    fn test_describe_agent_log_lines_property_each_tool_use_is_one_line(
        commands in proptest::collection::vec(any_detail(), 0..6),
        thinking in any::<String>(),
    ) {
        let mut content = Vec::new();
        let mut expected = Vec::new();
        for command in &commands {
            content.push(json!({"type": "thinking", "thinking": thinking}));
            content.push(json!({
                "type": "tool_use",
                "name": "Bash",
                "input": {"command": command},
            }));
            expected.push(normal_line(&format!("Ran {command}")));
        }

        let log_lines =
            describe_claude_log(&assistant_line(&Value::Array(content)));

        prop_assert_eq!(log_lines, expected);
    }

    #[test]
    fn test_describe_agent_log_lines_property_said_is_one_short_line(
        text in any::<String>(),
    ) {
        prop_assume!(has_content(&text) && !reads_as_json(&text));

        let log_lines = describe_claude_log(&said_line(&text));

        prop_assert_eq!(log_lines.len(), 1);
        let shown = log_lines[0].text.strip_prefix(SAID_PREFIX);
        prop_assert!(shown.is_some_and(|said| is_shortened_from(said, &text)));
        prop_assert!(!log_lines[0].is_error);
    }

    #[test]
    fn test_describe_agent_log_lines_property_json_speech_stays_out(
        key in "[a-z]{1,10}",
        text in any::<String>(),
    ) {
        let drafted = json!({key: text}).to_string();

        prop_assert_eq!(describe_claude_log(&said_line(&drafted)), Vec::new());
    }

    #[test]
    fn test_describe_agent_log_lines_property_tool_errors_are_errors(
        content in any_tool_result_content(),
    ) {
        let given_error = read_tool_result_text(&content);
        let error_text = if given_error.is_empty() {
            UNKNOWN_TOOL_FAILURE.to_string()
        } else {
            given_error
        };
        prop_assume!(!reads_as_json(&error_text));

        let failed_line = tool_result_line(&content, ToolOutcome::Failed);
        let succeeded_line =
            tool_result_line(&content, ToolOutcome::Succeeded);
        let failed = describe_claude_log(&failed_line);
        let succeeded = describe_claude_log(&succeeded_line);

        prop_assert_eq!(failed.len(), 1);
        prop_assert!(failed[0].is_error);
        prop_assert!(is_shortened_from(&failed[0].text, &error_text));
        prop_assert_eq!(succeeded, Vec::new());
    }

    #[test]
    fn test_describe_agent_log_lines_property_results_close_the_log(
        reason in any::<String>()
            .prop_filter("has a reason", |text| has_content(text)),
    ) {
        prop_assume!(!reads_as_json(&reason));

        let finished =
            describe_claude_log(&result_line(Ending::Finished, &reason));
        let failed =
            describe_claude_log(&result_line(Ending::Failed, &reason));

        prop_assert_eq!(finished, vec![normal_line(FINISHED_TEXT)]);
        prop_assert_eq!(failed.len(), 1);
        prop_assert!(failed[0].is_error);
        let shown = failed[0].text.strip_prefix(FAILED_PREFIX);
        let is_readable_reason =
            shown.is_some_and(|text| is_shortened_from(text, &reason));
        prop_assert!(is_readable_reason);
    }

    #[test]
    fn test_describe_agent_log_lines_property_start_names_the_session(
        session in "[a-zA-Z0-9-]{1,40}",
    ) {
        let log_lines = describe_claude_log(&init_line(&session));

        let expected = normal_line(&format!("{SESSION_PREFIX}{session}"));
        prop_assert_eq!(log_lines, vec![expected]);
    }

    #[test]
    fn test_describe_agent_log_lines_property_plain_lines_stay_plain(
        agent in any_agent(),
        line in "[ -~]{0,40}",
    ) {
        prop_assume!(!reads_as_json(&line));

        let log_lines = describe_log(agent, &line);

        let mut expected = Vec::new();
        if !line.trim().is_empty() {
            expected.push(normal_line(line.trim_end()));
        }
        prop_assert_eq!(log_lines, expected);
    }

    #[test]
    fn test_describe_agent_log_lines_property_colours_leave_plain_lines(
        agent in any_agent(),
        text in "[a-zA-Z0-9:][a-zA-Z0-9: ]{0,30}",
    ) {
        let coloured = format!("\u{1b}[31m{text}\u{1b}[0m\r");

        let log_lines = describe_log(agent, &coloured);

        prop_assert_eq!(log_lines, vec![normal_line(text.trim_end())]);
    }

    #[test]
    fn test_describe_agent_log_lines_property_unread_json_stays_out(
        agent in any_unparsed_agent(),
        event_type in "[a-z_.]{1,16}",
        text in any::<String>(),
    ) {
        let line = json!({"type": event_type, "text": text}).to_string();

        prop_assert_eq!(describe_log(agent, &line), Vec::new());
    }

    #[test]
    fn test_describe_agent_log_lines_property_no_output_shows_as_json(
        agent in any_agent(),
        line in any::<String>(),
    ) {
        for log_line in describe_log(agent, &line) {
            prop_assert!(!reads_as_json(&log_line.text));
            prop_assert!(has_content(&log_line.text));
        }
    }
}

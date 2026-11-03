use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;
use serde_json::json;

use crate::gemini_lines::{
    GEMINI_FILE_TOOLS, GEMINI_TEXT_TOOLS, any_gemini_line, any_speech_parts,
    error_event_line, finished_line, init_line, known_gemini_tools,
    message_line, result_line, speech_lines, tool_result_line, tool_use_line,
};
use crate::json_texts::{join_words, reads_as_json};
use crate::stream_support::{
    UNKNOWN_AGENT_ERROR, UNKNOWN_FAILURE_REASON, UNKNOWN_TOOL_FAILURE,
    any_relative_path, any_tool_detail, describe_container_log, error_line,
    expect_given_text, fixture_lines, normal_line, read_container_events,
    shows_no_raw_line, used_tool,
};

const GEMINI_STREAM: &str = include_str!("../fixtures/gemini_stream.jsonl");
const SESSION: &str = "c2a9e3f1-4b7d-4e2a-9f61-8d3b5a7c1e04";
const MISSING_FILE: &str = "File not found: hello-counter/src/count.ts";

fn read_gemini(lines: &[String]) -> Vec<AgentEvent> {
    read_container_events(AgentKind::GeminiCli, lines)
}

fn read_gemini_line(line: &str) -> Vec<AgentEvent> {
    read_gemini(&[line.to_string()])
}

fn expect_speech(parts: &[String]) -> Vec<AgentEvent> {
    let speech = parts.concat();
    if speech.trim().is_empty() {
        return Vec::new();
    }
    vec![AgentEvent::Said(speech.trim().to_string())]
}

fn with_line(lines: &[String], last_line: String) -> Vec<String> {
    let mut all_lines = lines.to_vec();
    all_lines.push(last_line);
    all_lines
}

#[test]
fn reads_a_recorded_gemini_run_into_events() {
    let events = read_gemini(&fixture_lines(GEMINI_STREAM));

    let expected = vec![
        AgentEvent::SessionStarted(SESSION.to_string()),
        AgentEvent::Said("I'll read the counter first.".to_string()),
        used_tool("Read hello-counter/src/count.ts"),
        AgentEvent::ToolFailed(MISSING_FILE.to_string()),
        used_tool("Read hello-counter/src/counter.ts"),
        used_tool("Edited hello-counter/src/counter.ts"),
        used_tool("Ran npm test"),
        AgentEvent::Said("The counter counts up now.".to_string()),
        AgentEvent::Finished,
    ];
    assert_eq!(events, expected);
}

#[test]
fn describes_a_recorded_gemini_run_as_readable_lines() {
    let lines = fixture_lines(GEMINI_STREAM);

    let log_lines = describe_container_log(AgentKind::GeminiCli, &lines);

    let expected = vec![
        normal_line(&format!("Agent started, session {SESSION}")),
        normal_line("Said: I'll read the counter first."),
        normal_line("Read hello-counter/src/count.ts"),
        error_line(MISSING_FILE),
        normal_line("Read hello-counter/src/counter.ts"),
        normal_line("Edited hello-counter/src/counter.ts"),
        normal_line("Ran npm test"),
        normal_line("Said: The counter counts up now."),
        normal_line("Finished"),
    ];
    assert_eq!(log_lines, expected);
}

proptest! {
    #[test]
    fn test_read_line_property_gemini_init_names_the_session(
        session in "[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}",
    ) {
        let events = read_gemini_line(&init_line(&session));

        prop_assert_eq!(events, vec![AgentEvent::SessionStarted(session)]);
    }

    #[test]
    fn test_read_line_property_gemini_speech_waits_for_the_next_event(
        parts in any_speech_parts(),
    ) {
        let events = read_gemini(&speech_lines(&parts));

        prop_assert_eq!(events, Vec::new());
    }

    #[test]
    fn test_read_line_property_gemini_speech_parts_join_into_one_said(
        parts in any_speech_parts(),
        command in any_tool_detail(),
    ) {
        let speech = speech_lines(&parts);
        let tool_use =
            tool_use_line("run_shell_command", &json!({"command": command}));

        let before_tool = read_gemini(&with_line(&speech, tool_use));
        let before_end = read_gemini(&with_line(&speech, finished_line()));

        let mut expected_before_tool = expect_speech(&parts);
        expected_before_tool.push(used_tool(&format!("Ran {command}")));
        let mut expected_before_end = expect_speech(&parts);
        expected_before_end.push(AgentEvent::Finished);
        prop_assert_eq!(before_tool, expected_before_tool);
        prop_assert_eq!(before_end, expected_before_end);
    }

    #[test]
    fn test_read_line_property_gemini_printed_lines_leave_speech_waiting(
        parts in any_speech_parts(),
        printed in "[a-zA-Z][a-zA-Z0-9 .:]{0,30}[a-zA-Z0-9.]",
    ) {
        let speech = speech_lines(&parts);
        let interrupted = with_line(&speech, printed.clone());

        let events = read_gemini(&with_line(&interrupted, finished_line()));

        let mut expected = vec![AgentEvent::Said(printed)];
        expected.extend(expect_speech(&parts));
        expected.push(AgentEvent::Finished);
        prop_assert_eq!(events, expected);
    }

    #[test]
    fn test_read_line_property_gemini_user_messages_give_nothing(
        content in any::<String>(),
    ) {
        let events = read_gemini_line(&message_line("user", &content));

        prop_assert_eq!(events, Vec::new());
    }

    #[test]
    fn test_read_line_property_gemini_text_tools_are_described(
        (tool, field, verb) in proptest::sample::select(
            GEMINI_TEXT_TOOLS.to_vec(),
        ),
        detail in any_tool_detail(),
    ) {
        let events = read_gemini_line(&tool_use_line(tool, &json!({
            field: detail,
        })));

        prop_assert_eq!(events, vec![used_tool(&format!("{verb} {detail}"))]);
    }

    #[test]
    fn test_read_line_property_gemini_file_tools_name_relative_paths(
        (tool, field, verb) in proptest::sample::select(
            GEMINI_FILE_TOOLS.to_vec(),
        ),
        relative_path in any_relative_path(),
    ) {
        let path = format!("/workspace/{relative_path}");

        let events = read_gemini_line(&tool_use_line(tool, &json!({
            field: path,
        })));

        let expected = used_tool(&format!("{verb} {relative_path}"));
        prop_assert_eq!(events, vec![expected]);
    }

    #[test]
    fn test_read_line_property_gemini_other_tools_are_named(
        tool in "[a-z][a-z_]{0,30}",
        detail in any_tool_detail(),
    ) {
        let known = known_gemini_tools();
        prop_assume!(!known.iter().any(|(name, _, _)| *name == tool));

        let parameters = json!({"file_path": detail, "command": detail});
        let events = read_gemini_line(&tool_use_line(&tool, &parameters));

        prop_assert_eq!(events, vec![used_tool(&format!("Used {tool}"))]);
    }

    #[test]
    fn test_read_line_property_gemini_tool_results_report_only_errors(
        output in proptest::option::of(any::<String>()),
        message in proptest::option::of(any::<String>()),
    ) {
        let output_text = output.as_deref();
        let message_text = message.as_deref();

        let succeeded = read_gemini_line(&tool_result_line(
            "success",
            output_text,
            None,
        ));
        let failed = read_gemini_line(&tool_result_line(
            "error",
            output_text,
            message_text,
        ));

        let given_message = message_text.unwrap_or_default().trim();
        let given_output = output_text.unwrap_or_default();
        let error = if given_message.is_empty() {
            expect_given_text(given_output, UNKNOWN_TOOL_FAILURE)
        } else {
            given_message.to_string()
        };
        prop_assert_eq!(succeeded, Vec::new());
        prop_assert_eq!(failed, vec![AgentEvent::ToolFailed(error)]);
    }

    #[test]
    fn test_read_line_property_gemini_results_close_the_run(
        error_type in "[A-Za-z_]{0,20}",
        message in any::<String>(),
    ) {
        let error = Some((error_type.as_str(), message.as_str()));

        let finished = read_gemini_line(&finished_line());
        let failed = read_gemini_line(&result_line("error", error));

        let reason = if message.trim().is_empty() {
            expect_given_text(&error_type, UNKNOWN_FAILURE_REASON)
        } else {
            message.trim().to_string()
        };
        prop_assert_eq!(finished, vec![AgentEvent::Finished]);
        prop_assert_eq!(failed, vec![AgentEvent::Failed(reason)]);
    }

    #[test]
    fn test_read_line_property_gemini_errors_are_tool_failures(
        severity in prop_oneof![Just("warning"), Just("error")],
        message in any::<String>(),
    ) {
        let events = read_gemini_line(&error_event_line(severity, &message));

        let error = expect_given_text(&message, UNKNOWN_AGENT_ERROR);
        prop_assert_eq!(events, vec![AgentEvent::ToolFailed(error)]);
    }

    #[test]
    fn test_describe_agent_log_lines_property_gemini_never_shows_raw_json(
        lines in proptest::collection::vec(any_gemini_line(), 0..10),
    ) {
        let log_lines = describe_container_log(AgentKind::GeminiCli, &lines);

        prop_assert!(shows_no_raw_line(&log_lines, &lines));
    }

    #[test]
    fn test_describe_agent_log_lines_property_gemini_speech_is_one_line(
        parts in proptest::collection::vec("[a-z ]{1,10}", 1..6),
    ) {
        let joined = join_words(&parts.concat());
        prop_assume!(!joined.is_empty() && !reads_as_json(&joined));
        let lines = with_line(&speech_lines(&parts), finished_line());

        let log_lines = describe_container_log(AgentKind::GeminiCli, &lines);

        let expected = vec![
            normal_line(&format!("Said: {joined}")),
            normal_line("Finished"),
        ];
        prop_assert_eq!(log_lines, expected);
    }

    #[test]
    fn test_describe_agent_log_lines_property_gemini_tools_are_one_line_each(
        commands in proptest::collection::vec(any_tool_detail(), 0..6),
    ) {
        let mut lines = Vec::new();
        let mut expected = Vec::new();
        for command in &commands {
            let parameters = json!({"command": command});
            lines.push(tool_use_line("run_shell_command", &parameters));
            lines.push(tool_result_line("success", Some(command), None));
            expected.push(normal_line(&format!("Ran {command}")));
        }

        let log_lines = describe_container_log(AgentKind::GeminiCli, &lines);

        prop_assert_eq!(log_lines, expected);
    }
}

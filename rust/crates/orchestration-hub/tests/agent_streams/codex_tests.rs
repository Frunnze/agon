use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;
use serde_json::json;

use crate::codex_lines::{
    agent_message, any_codex_line, any_file_change_kind, any_finished_status,
    codex_event, command_item, completed_line, error_line_of,
    file_change_item, started_line, thread_started_line, tool_call_item,
    turn_failed_line,
};
use crate::stream_support::{
    UNKNOWN_AGENT_ERROR, UNKNOWN_FAILURE_REASON, UNKNOWN_TOOL_FAILURE,
    any_relative_path, any_tool_detail, describe_container_log, error_line,
    expect_given_text, fixture_lines, normal_line, read_container_events,
    shows_no_raw_line, used_tool,
};

const CODEX_STREAM: &str = include_str!("../fixtures/codex_stream.jsonl");
const THREAD: &str = "0199a213-81c0-7800-8aa1-bbab2a035a53";
const TEST_FAILURE: &str =
    "FAIL src/counter.test.ts\n  counts up: expected 1, received -1";
const SHELLS: [&str; 4] = ["bash", "/bin/bash", "/bin/zsh", "sh"];
const QUOTES: [&str; 3] = ["'", "\"", ""];
const READ_CODEX_EVENT_TYPES: [&str; 5] = [
    "thread.started",
    "item.started",
    "item.completed",
    "turn.completed",
    "turn.failed",
];

fn read_codex(lines: &[String]) -> Vec<AgentEvent> {
    read_container_events(AgentKind::Codex, lines)
}

fn read_codex_line(line: &str) -> Vec<AgentEvent> {
    read_codex(&[line.to_string()])
}

#[test]
fn reads_a_recorded_codex_run_into_events() {
    let events = read_codex(&fixture_lines(CODEX_STREAM));

    let expected = vec![
        AgentEvent::SessionStarted(THREAD.to_string()),
        AgentEvent::Said("I'll run the tests first.".to_string()),
        used_tool("Ran npm test"),
        AgentEvent::ToolFailed(TEST_FAILURE.to_string()),
        used_tool("Edited hello-counter/src/counter.ts"),
        used_tool("Wrote hello-counter/src/counter.test.ts"),
        used_tool("Ran npm test"),
        AgentEvent::Said(
            "The counter counts up now and the tests pass.".to_string(),
        ),
        AgentEvent::Finished,
    ];
    assert_eq!(events, expected);
}

#[test]
fn describes_a_recorded_codex_run_as_readable_lines() {
    let log_lines =
        describe_container_log(AgentKind::Codex, &fixture_lines(CODEX_STREAM));

    let expected = vec![
        normal_line(&format!("Agent started, session {THREAD}")),
        normal_line("Said: I'll run the tests first."),
        normal_line("Ran npm test"),
        error_line(
            "FAIL src/counter.test.ts counts up: expected 1, received -1",
        ),
        normal_line("Edited hello-counter/src/counter.ts"),
        normal_line("Wrote hello-counter/src/counter.test.ts"),
        normal_line("Ran npm test"),
        normal_line("Said: The counter counts up now and the tests pass."),
        normal_line("Finished"),
    ];
    assert_eq!(log_lines, expected);
}

proptest! {
    #[test]
    fn test_read_line_property_codex_thread_start_names_the_session(
        thread in "[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}",
    ) {
        let events = read_codex_line(&thread_started_line(&thread));

        prop_assert_eq!(events, vec![AgentEvent::SessionStarted(thread)]);
    }

    #[test]
    fn test_read_line_property_codex_agent_messages_are_said(
        text in any::<String>(),
    ) {
        let events = read_codex_line(&completed_line(&agent_message(&text)));

        let mut expected = Vec::new();
        if !text.trim().is_empty() {
            expected.push(AgentEvent::Said(text.trim().to_string()));
        }
        prop_assert_eq!(events, expected);
    }

    #[test]
    fn test_read_line_property_codex_started_commands_are_described(
        command in any_tool_detail(),
        output in any::<String>(),
    ) {
        let item = command_item(&command, "in_progress", &output);

        let events = read_codex_line(&started_line(&item));

        prop_assert_eq!(events, vec![used_tool(&format!("Ran {command}"))]);
    }

    #[test]
    fn test_read_line_property_codex_shell_wrappers_are_unwrapped(
        shell in proptest::sample::select(SHELLS.to_vec()),
        quote in proptest::sample::select(QUOTES.to_vec()),
        script in "[a-z][a-z0-9 ./=-]{0,40}[a-z0-9]",
    ) {
        let command = format!("{shell} -lc {quote}{script}{quote}");
        let item = command_item(&command, "in_progress", "");

        let events = read_codex_line(&started_line(&item));

        prop_assert_eq!(events, vec![used_tool(&format!("Ran {script}"))]);
    }

    #[test]
    fn test_read_line_property_codex_finished_commands_report_failures(
        command in any_tool_detail(),
        status in any_finished_status(),
        output in any::<String>(),
    ) {
        let item = command_item(&command, status, &output);

        let events = read_codex_line(&completed_line(&item));

        let mut expected = Vec::new();
        if status != "completed" {
            let error = expect_given_text(&output, UNKNOWN_TOOL_FAILURE);
            expected.push(AgentEvent::ToolFailed(error));
        }
        prop_assert_eq!(events, expected);
    }

    #[test]
    fn test_read_line_property_codex_file_changes_give_one_line_each(
        changes in proptest::collection::vec(
            (any_relative_path(), any_file_change_kind()),
            1..5,
        ),
        has_failed in any::<bool>(),
    ) {
        let mut rendered = Vec::new();
        let mut expected = Vec::new();
        for (relative_path, (kind, verb)) in &changes {
            let path = format!("/workspace/{relative_path}");
            rendered.push((path, (*kind).to_string()));
            expected.push(used_tool(&format!("{verb} {relative_path}")));
        }
        let status = if has_failed { "failed" } else { "completed" };
        if has_failed {
            let failure = UNKNOWN_TOOL_FAILURE.to_string();
            expected.push(AgentEvent::ToolFailed(failure));
        }
        let item = file_change_item(&rendered, status);

        let started = read_codex_line(&started_line(&item));
        let completed = read_codex_line(&completed_line(&item));

        prop_assert_eq!(started, Vec::new());
        prop_assert_eq!(completed, expected);
    }

    #[test]
    fn test_read_line_property_codex_tool_calls_are_described(
        tool in "[a-z][a-z_]{0,20}",
        error in proptest::option::of(any::<String>()),
        query in any_tool_detail(),
    ) {
        let started = tool_call_item(&tool, "in_progress", None);
        let failed = tool_call_item(&tool, "failed", error.as_deref());
        let search =
            json!({"id": "ws_1", "type": "web_search", "query": query});

        let started_events = read_codex_line(&started_line(&started));
        let failed_events = read_codex_line(&completed_line(&failed));
        let search_events = read_codex_line(&completed_line(&search));

        let given_error = error.unwrap_or_default();
        let failure = expect_given_text(&given_error, UNKNOWN_TOOL_FAILURE);
        let used = format!("Used {tool}");
        let searched = format!("Searched the web for {query}");
        prop_assert_eq!(started_events, vec![used_tool(&used)]);
        prop_assert_eq!(failed_events, vec![AgentEvent::ToolFailed(failure)]);
        prop_assert_eq!(search_events, vec![used_tool(&searched)]);
    }

    #[test]
    fn test_read_line_property_codex_turn_endings_close_the_run(
        message in any::<String>(),
    ) {
        let finished = read_codex_line(&codex_event("turn.completed"));
        let failed = read_codex_line(&turn_failed_line(&message));

        let reason = expect_given_text(&message, UNKNOWN_FAILURE_REASON);
        prop_assert_eq!(finished, vec![AgentEvent::Finished]);
        prop_assert_eq!(failed, vec![AgentEvent::Failed(reason)]);
    }

    #[test]
    fn test_read_line_property_codex_errors_are_tool_failures(
        message in any::<String>(),
    ) {
        let error_item =
            json!({"id": "e", "type": "error", "message": message});

        let thread_error = read_codex_line(&error_line_of(&message));
        let item_error = read_codex_line(&completed_line(&error_item));

        let error = expect_given_text(&message, UNKNOWN_AGENT_ERROR);
        let expected = vec![AgentEvent::ToolFailed(error)];
        prop_assert_eq!(&thread_error, &expected);
        prop_assert_eq!(&item_error, &expected);
    }

    #[test]
    fn test_read_line_property_codex_quiet_events_give_nothing(
        text in any::<String>(),
        event_type in "[a-z_]{1,12}\\.[a-z_]{1,12}",
    ) {
        prop_assume!(!READ_CODEX_EVENT_TYPES.contains(&event_type.as_str()));
        let reasoning = json!({"id": "r", "type": "reasoning", "text": text});
        let todo = json!({"id": "t", "type": "todo_list", "items": []});
        let unknown = json!({"type": event_type, "text": text});
        let quiet_lines = vec![
            codex_event("turn.started"),
            completed_line(&reasoning),
            started_line(&todo),
            unknown.to_string(),
        ];

        for line in &quiet_lines {
            prop_assert_eq!(read_codex_line(line), Vec::new());
        }
    }

    #[test]
    fn test_describe_agent_log_lines_property_codex_never_shows_raw_json(
        lines in proptest::collection::vec(any_codex_line(), 0..10),
    ) {
        let log_lines = describe_container_log(AgentKind::Codex, &lines);

        prop_assert!(shows_no_raw_line(&log_lines, &lines));
    }

    #[test]
    fn test_describe_agent_log_lines_property_codex_tools_are_one_line_each(
        commands in proptest::collection::vec(any_tool_detail(), 0..6),
    ) {
        let mut lines = Vec::new();
        let mut expected = Vec::new();
        for command in &commands {
            let item = command_item(command, "in_progress", "");
            lines.push(started_line(&item));
            let finished = command_item(command, "completed", "");
            lines.push(completed_line(&finished));
            expected.push(normal_line(&format!("Ran {command}")));
        }

        let log_lines = describe_container_log(AgentKind::Codex, &lines);

        prop_assert_eq!(log_lines, expected);
    }
}

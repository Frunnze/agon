use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::json;

use crate::agent_reading::parse_agent_line;
use crate::claude_lines::assistant_line;
use crate::codex_lines::{
    FILE_CHANGE_VERBS, any_file_change_kind, command_item, completed_line,
    file_change_item, tool_call_item,
};
use crate::stream_support::{
    UNKNOWN_TOOL_FAILURE, any_relative_path, expect_given_text,
};

const FAILED_STATUSES: [&str; 2] = ["failed", "declined"];
const OTHER_STATUSES: [&str; 7] = [
    "completed",
    "in_progress",
    "Failed",
    "DECLINED",
    " failed",
    "declined ",
    "",
];
const CHANGED_VERB: &str = "Changed";
const LARGEST_CHANGE_COUNT: usize = 5;

type FileChange = (String, String);

fn parse_codex(line: &str) -> Vec<AgentEvent> {
    parse_agent_line(AgentKind::Codex, line)
}

fn any_failed_status() -> impl Strategy<Value = &'static str> {
    proptest::sample::select(FAILED_STATUSES.to_vec())
}

fn any_status() -> impl Strategy<Value = &'static str> {
    let mut statuses = FAILED_STATUSES.to_vec();
    statuses.extend(OTHER_STATUSES);
    proptest::sample::select(statuses)
}

fn task_file(relative_path: &str) -> String {
    format!("{CONTAINER_WORKSPACE_DIRECTORY}/{relative_path}")
}

fn any_change() -> impl Strategy<Value = (String, &'static str)> {
    (any_relative_path(), any_file_change_kind())
        .prop_map(|(relative_path, (_kind, verb))| (relative_path, verb))
}

fn any_unknown_kind() -> impl Strategy<Value = String> {
    "[a-zA-Z ]{0,8}".prop_filter("an unknown kind", |kind| {
        !FILE_CHANGE_VERBS.iter().any(|(known, _verb)| known == kind)
    })
}

fn kind_of(verb: &str) -> String {
    let known = FILE_CHANGE_VERBS
        .iter()
        .find(|(_kind, known)| *known == verb);
    known
        .map(|(kind, _verb)| (*kind).to_owned())
        .unwrap_or_default()
}

fn render_changes(changes: &[(String, &str)]) -> Vec<FileChange> {
    let mut rendered = Vec::new();
    for (relative_path, verb) in changes {
        rendered.push((task_file(relative_path), kind_of(verb)));
    }
    rendered
}

fn describe_changes(changes: &[(String, &str)]) -> Vec<AgentEvent> {
    let mut agent_events = Vec::new();
    for (relative_path, verb) in changes {
        let description = format!("{verb} {relative_path}");
        agent_events.push(AgentEvent::UsedTool(description));
    }
    agent_events
}

fn describe_one_change(path: &str, kind: &str) -> Vec<AgentEvent> {
    let change = (path.to_owned(), kind.to_owned());
    parse_codex(&completed_line(&file_change_item(&[change], "completed")))
}

fn unknown_failure() -> AgentEvent {
    AgentEvent::ToolFailed(UNKNOWN_TOOL_FAILURE.to_owned())
}

fn describe_failed_patch(changes: &[(String, &str)]) -> AgentEvent {
    if changes.is_empty() {
        return unknown_failure();
    }
    let mut relative_paths = Vec::new();
    for (relative_path, _verb) in changes {
        relative_paths.push(relative_path.as_str());
    }
    let named_paths = relative_paths.join(", ");
    AgentEvent::ToolFailed(format!("Could not change {named_paths}"))
}

proptest! {
    #[test]
    fn test_describe_failure_property_only_failed_or_declined_report(
        status in any_status(),
        output in "[a-z ]{0,20}",
    ) {
        let item = command_item("cargo test", status, &output);

        let agent_events = parse_codex(&completed_line(&item));

        let has_failed = FAILED_STATUSES.contains(&status);
        prop_assert_eq!(!agent_events.is_empty(), has_failed);
    }

    #[test]
    fn test_describe_failure_property_reason_is_the_trimmed_output(
        status in any_failed_status(),
        output in any::<String>(),
        padding in "[ \n\t]{0,3}",
    ) {
        let padded = format!("{padding}{output}{padding}");
        let item = command_item("cargo test", status, &padded);

        let agent_events = parse_codex(&completed_line(&item));

        let error = expect_given_text(&output, UNKNOWN_TOOL_FAILURE);
        prop_assert_eq!(agent_events, vec![AgentEvent::ToolFailed(error)]);
    }

    #[test]
    fn test_describe_failure_property_tool_calls_report_their_error(
        status in any_failed_status(),
        message in proptest::option::of(any::<String>()),
    ) {
        let item = tool_call_item("search", status, message.as_deref());

        let agent_events = parse_codex(&completed_line(&item));

        let given_message = message.unwrap_or_default();
        let error = expect_given_text(&given_message, UNKNOWN_TOOL_FAILURE);
        prop_assert_eq!(agent_events, vec![AgentEvent::ToolFailed(error)]);
    }

    #[test]
    fn test_describe_file_changes_property_one_line_per_change_in_order(
        changes in vec(any_change(), 0..LARGEST_CHANGE_COUNT),
    ) {
        let item = file_change_item(&render_changes(&changes), "completed");

        let agent_events = parse_codex(&completed_line(&item));

        prop_assert_eq!(agent_events, describe_changes(&changes));
    }

    #[test]
    fn test_describe_file_changes_property_failed_patches_only_fail(
        changes in vec(any_change(), 0..LARGEST_CHANGE_COUNT),
        status in any_failed_status(),
    ) {
        let item = file_change_item(&render_changes(&changes), status);

        let agent_events = parse_codex(&completed_line(&item));

        prop_assert_eq!(agent_events, vec![describe_failed_patch(&changes)]);
    }

    #[test]
    fn test_describe_file_changes_property_outside_paths_stay_whole(
        outside_path in "/[a-z]{1,8}(/[a-z0-9_.-]{1,8}){0,3}",
        blank in "[ \t]{0,3}",
    ) {
        prop_assume!(!outside_path.starts_with(CONTAINER_WORKSPACE_DIRECTORY));

        let outside = describe_one_change(&outside_path, "update");
        let workspace = CONTAINER_WORKSPACE_DIRECTORY;
        let task_root = describe_one_change(workspace, "add");
        let unnamed = describe_one_change(&blank, "delete");

        let edited = format!("Edited {outside_path}");
        prop_assert_eq!(outside, vec![AgentEvent::UsedTool(edited)]);
        let wrote = format!("Wrote {CONTAINER_WORKSPACE_DIRECTORY}");
        prop_assert_eq!(task_root, vec![AgentEvent::UsedTool(wrote)]);
        let used = AgentEvent::UsedTool("Used apply_patch".to_owned());
        prop_assert_eq!(unnamed, vec![used]);
    }

    #[test]
    fn test_choose_file_change_action_property_known_kinds_pick_a_verb(
        relative_path in any_relative_path(),
        (kind, verb) in any_file_change_kind(),
    ) {
        let file_path = task_file(&relative_path);
        let agent_events = describe_one_change(&file_path, kind);

        let description = format!("{verb} {relative_path}");
        prop_assert_eq!(agent_events, vec![AgentEvent::UsedTool(description)]);
    }

    #[test]
    fn test_choose_file_change_action_property_unknown_kinds_are_changed(
        relative_path in any_relative_path(),
        kind in any_unknown_kind(),
    ) {
        let file_path = task_file(&relative_path);
        let agent_events = describe_one_change(&file_path, &kind);

        let description = format!("{CHANGED_VERB} {relative_path}");
        prop_assert_eq!(agent_events, vec![AgentEvent::UsedTool(description)]);
    }

    #[test]
    fn test_choose_file_change_action_property_verbs_agree_with_claude(
        relative_path in any_relative_path(),
        (codex_kind, claude_tool) in prop_oneof![
            Just(("add", "Write")),
            Just(("update", "Edit")),
        ],
    ) {
        let file_path = task_file(&relative_path);
        let tool_use = json!({
            "type": "tool_use",
            "name": claude_tool,
            "input": {"file_path": file_path},
        });
        let claude_line = assistant_line(&json!([tool_use]));

        let codex_events = describe_one_change(&file_path, codex_kind);
        let claude_events =
            parse_agent_line(AgentKind::ClaudeCode, &claude_line);

        prop_assert_eq!(codex_events, claude_events);
    }
}

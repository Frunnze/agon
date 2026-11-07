use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_log::describe_agent_log_lines;
use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::agent_reading::parse_agent_line;
use crate::codex_lines::{
    FILE_CHANGE_VERBS, any_file_change_kind, completed_line, file_change_item,
};
use crate::stream_support::{UNKNOWN_TOOL_FAILURE, any_relative_path};

const FAILED_STATUSES: [&str; 2] = ["failed", "declined"];
const COMPLETED_STATUS: &str = "completed";
const LARGEST_CHANGE_COUNT: usize = 5;

type FileChange = (String, String);

fn any_failed_status() -> impl Strategy<Value = &'static str> {
    proptest::sample::select(FAILED_STATUSES.to_vec())
}

fn any_changes() -> impl Strategy<Value = Vec<FileChange>> {
    vec(
        (any_relative_path(), any_file_change_kind()),
        0..LARGEST_CHANGE_COUNT,
    )
    .prop_map(|changes| {
        let mut rendered = Vec::new();
        for (relative_path, (kind, _verb)) in changes {
            let path =
                format!("{CONTAINER_WORKSPACE_DIRECTORY}/{relative_path}");
            rendered.push((path, kind.to_owned()));
        }
        rendered
    })
}

fn patch_line(changes: &[FileChange], status: &str) -> String {
    completed_line(&file_change_item(changes, status))
}

fn read_patch(changes: &[FileChange], status: &str) -> Vec<AgentEvent> {
    parse_agent_line(AgentKind::Codex, &patch_line(changes, status))
}

fn tool_failure(changes: &[FileChange]) -> AgentEvent {
    if changes.is_empty() {
        return AgentEvent::ToolFailed(UNKNOWN_TOOL_FAILURE.to_owned());
    }
    let workspace_prefix = format!("{CONTAINER_WORKSPACE_DIRECTORY}/");
    let mut relative_paths = Vec::new();
    for (path, _kind) in changes {
        let relative_path =
            path.strip_prefix(&workspace_prefix).unwrap_or(path);
        relative_paths.push(relative_path);
    }
    let named_paths = relative_paths.join(", ");
    AgentEvent::ToolFailed(format!("Could not change {named_paths}"))
}

proptest! {
    #[test]
    fn test_describe_file_changes_property_failed_patches_claim_no_edits(
        changes in any_changes(),
        status in any_failed_status(),
    ) {
        let agent_events = read_patch(&changes, status);

        prop_assert_eq!(agent_events, vec![tool_failure(&changes)]);
    }

    #[test]
    fn test_describe_file_changes_property_failed_patches_log_an_error(
        changes in any_changes(),
        status in any_failed_status(),
    ) {
        let line = patch_line(&changes, status);
        let agent_events = parse_agent_line(AgentKind::Codex, &line);

        let log_lines = describe_agent_log_lines(&line, &agent_events);

        prop_assert!(log_lines.iter().any(|log_line| log_line.is_error));
        for log_line in &log_lines {
            let claims_an_edit = FILE_CHANGE_VERBS
                .iter()
                .any(|(_kind, verb)| log_line.text.starts_with(verb));
            prop_assert!(!claims_an_edit, "{}", log_line.text);
        }
    }

    #[test]
    fn test_describe_file_changes_property_only_finished_patches_list_edits(
        first_changes in any_changes(),
        second_changes in any_changes(),
        status in any_failed_status(),
    ) {
        let first_failure = read_patch(&first_changes, status);
        let second_failure = read_patch(&second_changes, status);
        let completed = read_patch(&first_changes, COMPLETED_STATUS);

        prop_assert_eq!(first_failure, vec![tool_failure(&first_changes)]);
        prop_assert_eq!(second_failure, vec![tool_failure(&second_changes)]);
        prop_assert_eq!(completed.len(), first_changes.len());
        let lists_edits = completed
            .iter()
            .all(|agent_event| matches!(agent_event, AgentEvent::UsedTool(_)));
        prop_assert!(lists_edits);
    }
}

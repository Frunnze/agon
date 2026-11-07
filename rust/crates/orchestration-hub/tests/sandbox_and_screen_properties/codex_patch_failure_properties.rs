use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_log::describe_agent_log_lines;
use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::select;

use crate::agent_reading::parse_agent_line;
use crate::codex_lines::{
    FILE_CHANGE_VERBS, any_file_change_kind, completed_line, file_change_item,
};
use crate::stream_support::{UNKNOWN_TOOL_FAILURE, any_relative_path};

const FAILED_STATUSES: [&str; 2] = ["failed", "declined"];
const FAILED_PATCH_PREFIX: &str = "Could not change ";
const BLANK_PATHS: [&str; 4] = ["", " ", "\t", "\n "];
const SHORTENED_MARKER: char = '…';
const LONGEST_NAMED_PATH: usize = 100;

type FileChange = (String, String);

fn any_changes(
    largest_count: usize,
) -> impl Strategy<Value = (Vec<String>, Vec<FileChange>)> {
    vec(
        (any_relative_path(), any_file_change_kind()),
        1..largest_count,
    )
    .prop_map(|changes| {
        let mut relative_paths = Vec::new();
        let mut rendered = Vec::new();
        for (relative_path, (kind, _verb)) in changes {
            let path =
                format!("{CONTAINER_WORKSPACE_DIRECTORY}/{relative_path}");
            rendered.push((path, kind.to_owned()));
            relative_paths.push(relative_path);
        }
        (relative_paths, rendered)
    })
}

fn failed_patch_line(changes: &[FileChange], status: &str) -> String {
    completed_line(&file_change_item(changes, status))
}

fn failed_patch(relative_paths: &[String]) -> AgentEvent {
    let named_files = relative_paths.join(", ");
    AgentEvent::ToolFailed(format!("{FAILED_PATCH_PREFIX}{named_files}"))
}

proptest! {
    #[test]
    fn test_describe_failed_patch_property_names_every_changed_file(
        (relative_paths, changes) in any_changes(6),
        status in select(FAILED_STATUSES.to_vec()),
    ) {
        let line = failed_patch_line(&changes, status);

        let agent_events = parse_agent_line(AgentKind::Codex, &line);

        prop_assert_eq!(agent_events, vec![failed_patch(&relative_paths)]);
    }

    #[test]
    fn test_describe_failed_patch_property_unnamed_files_fall_back(
        blank_paths in vec(select(BLANK_PATHS.to_vec()), 0..4),
        status in select(FAILED_STATUSES.to_vec()),
        (kind, _verb) in any_file_change_kind(),
    ) {
        let mut changes = Vec::new();
        for blank_path in blank_paths {
            changes.push((blank_path.to_owned(), kind.to_owned()));
        }
        let line = failed_patch_line(&changes, status);

        let agent_events = parse_agent_line(AgentKind::Codex, &line);

        let failure = AgentEvent::ToolFailed(UNKNOWN_TOOL_FAILURE.to_owned());
        prop_assert_eq!(agent_events, vec![failure]);
    }

    #[test]
    fn test_describe_failed_patch_property_log_names_files_without_edits(
        (relative_paths, changes) in any_changes(3),
        status in select(FAILED_STATUSES.to_vec()),
    ) {
        let line = failed_patch_line(&changes, status);
        let agent_events = parse_agent_line(AgentKind::Codex, &line);

        let log_lines = describe_agent_log_lines(&line, &agent_events);

        prop_assert_eq!(log_lines.len(), 1);
        let log_line = &log_lines[0];
        prop_assert!(log_line.is_error);
        prop_assert!(log_line.text.starts_with(FAILED_PATCH_PREFIX));
        let first_path = &relative_paths[0];
        prop_assert!(log_line.text.contains(first_path.as_str()));
        for (_kind, verb) in FILE_CHANGE_VERBS {
            prop_assert!(!log_line.text.starts_with(verb));
        }
    }

    #[test]
    fn test_describe_file_path_property_task_paths_become_relative(
        (relative_paths, changes) in any_changes(4),
    ) {
        let completed = parse_agent_line(
            AgentKind::Codex,
            &failed_patch_line(&changes, "completed"),
        );
        let failed = parse_agent_line(
            AgentKind::Codex,
            &failed_patch_line(&changes, "failed"),
        );

        prop_assert_eq!(failed, vec![failed_patch(&relative_paths)]);
        let pairs = completed.iter().zip(&relative_paths);
        for (agent_event, relative_path) in pairs {
            let AgentEvent::UsedTool(description) = agent_event else {
                return Err(TestCaseError::fail("expected a used tool"));
            };
            prop_assert!(description.ends_with(relative_path.as_str()));
        }
    }

    #[test]
    fn test_describe_file_path_property_only_the_first_line_is_named(
        relative_path in any_relative_path(),
        rest in "[a-z /.]{0,20}",
        status in select(FAILED_STATUSES.to_vec()),
    ) {
        let path = format!("{CONTAINER_WORKSPACE_DIRECTORY}/{relative_path}");
        let changes = vec![(format!("{path}\n{rest}"), "update".to_owned())];

        let agent_events = parse_agent_line(
            AgentKind::Codex,
            &failed_patch_line(&changes, status),
        );

        prop_assert_eq!(agent_events, vec![failed_patch(&[relative_path])]);
    }

    #[test]
    fn test_describe_file_path_property_long_paths_keep_their_end(
        folders in vec("[a-z]{8,12}", 12..16),
        file_name in "[a-z]{1,10}\\.rs",
        status in select(FAILED_STATUSES.to_vec()),
    ) {
        let relative_path = format!("{}/{file_name}", folders.join("/"));
        let path = format!("{CONTAINER_WORKSPACE_DIRECTORY}/{relative_path}");
        let changes = vec![(path, "add".to_owned())];

        let agent_events = parse_agent_line(
            AgentKind::Codex,
            &failed_patch_line(&changes, status),
        );

        let [AgentEvent::ToolFailed(failure)] = agent_events.as_slice() else {
            return Err(TestCaseError::fail("expected one failure"));
        };
        let named_path = failure.trim_start_matches(FAILED_PATCH_PREFIX);
        prop_assert!(named_path.starts_with(SHORTENED_MARKER));
        let file_ending = format!("/{file_name}");
        prop_assert!(named_path.ends_with(&file_ending));
        prop_assert!(named_path.chars().count() <= LONGEST_NAMED_PATH + 1);
    }
}

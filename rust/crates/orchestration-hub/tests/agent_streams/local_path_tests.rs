use std::path::{Path, PathBuf};

use orchestration_core::device::SandboxKind;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::workspace_mounts::{
    CONTAINER_WORKSPACE_DIRECTORY, WorkspaceMounts,
    locate_task_folder_seen_by_agent,
};
use proptest::prelude::*;
use serde_json::json;

use crate::codex_lines::{completed_line, file_change_item};
use crate::gemini_lines::tool_use_line;
use crate::stream_support::{
    any_relative_path, describe_agent_log, normal_line, read_agent_events,
    read_container_events, used_tool,
};

const MAXIMUM_DETAIL_CHARACTERS: usize = 100;
const SHORTENED_PREFIX: &str = "Edited …";

fn any_agent() -> impl Strategy<Value = AgentKind> {
    prop_oneof![
        Just(AgentKind::ClaudeCode),
        Just(AgentKind::Codex),
        Just(AgentKind::GeminiCli),
    ]
}

fn any_task_folder() -> impl Strategy<Value = String> {
    "/(Users|home|private/var)/[a-z]{1,8}(/[a-z0-9-]{1,12}){1,3}"
}

fn any_folder_name() -> impl Strategy<Value = String> {
    "[a-z][a-z0-9-]{9,19}"
}

fn edit_line(agent: AgentKind, path: &str) -> String {
    match agent {
        AgentKind::ClaudeCode => json!({
            "type": "assistant",
            "message": {"content": [{
                "type": "tool_use",
                "name": "Edit",
                "input": {"file_path": path},
            }]},
        })
        .to_string(),
        AgentKind::Codex => {
            let change = (path.to_string(), "update".to_string());
            completed_line(&file_change_item(&[change], "completed"))
        }
        AgentKind::GeminiCli => {
            tool_use_line("replace", &json!({"file_path": path}))
        }
    }
}

fn read_local_edit(
    agent: AgentKind,
    task_folder: &str,
    path: &str,
) -> Vec<AgentEvent> {
    let lines = vec![edit_line(agent, path)];
    read_agent_events(agent, Path::new(task_folder), &lines)
}

fn edited(path: &str) -> Vec<AgentEvent> {
    vec![used_tool(&format!("Edited {path}"))]
}

proptest! {
    #[test]
    fn test_read_line_property_local_paths_drop_the_task_folder(
        agent in any_agent(),
        task_folder in any_task_folder(),
        relative_path in any_relative_path(),
    ) {
        let path = format!("{task_folder}/{relative_path}");

        let events = read_local_edit(agent, &task_folder, &path);

        prop_assert_eq!(events, edited(&relative_path));
    }

    #[test]
    fn test_read_line_property_long_local_paths_keep_the_file_name(
        agent in any_agent(),
        task_folder in any_task_folder(),
        folders in proptest::collection::vec(any_folder_name(), 10..14),
        file_name in "[a-z][a-z0-9_-]{0,20}\\.[a-z]{1,4}",
    ) {
        let relative_path = format!("{}/{file_name}", folders.join("/"));
        let path = format!("{task_folder}/{relative_path}");

        let events = read_local_edit(agent, &task_folder, &path);

        let [AgentEvent::UsedTool(description)] = events.as_slice() else {
            return Err(TestCaseError::fail("expected one tool event"));
        };
        let kept = description.strip_prefix(SHORTENED_PREFIX);
        let kept_path = kept.unwrap_or_default();
        let file_name_ending = format!("/{file_name}");
        prop_assert!(kept.is_some());
        prop_assert!(kept_path.ends_with(&file_name_ending));
        prop_assert!(relative_path.ends_with(kept_path));
        prop_assert!(kept_path.chars().count() <= MAXIMUM_DETAIL_CHARACTERS);
        prop_assert!(!description.contains(task_folder.as_str()));
    }

    #[test]
    fn test_read_line_property_paths_beside_the_task_folder_stay_as_given(
        agent in any_agent(),
        task_folder in any_task_folder(),
        sibling_suffix in "[a-z0-9-]{1,8}",
        relative_path in "[a-z]{1,10}/[a-z]{1,10}\\.[a-z]{2}",
    ) {
        let path = format!("{task_folder}{sibling_suffix}/{relative_path}");

        let events = read_local_edit(agent, &task_folder, &path);

        prop_assert_eq!(events, edited(&path));
    }

    #[test]
    fn test_read_line_property_container_paths_drop_the_workspace_folder(
        agent in any_agent(),
        relative_path in any_relative_path(),
    ) {
        let path = format!("{CONTAINER_WORKSPACE_DIRECTORY}/{relative_path}");
        let lines = vec![edit_line(agent, &path)];

        let events = read_container_events(agent, &lines);

        prop_assert_eq!(events, edited(&relative_path));
    }

    #[test]
    fn test_describe_agent_log_lines_property_local_edits_show_short_paths(
        agent in any_agent(),
        task_folder in any_task_folder(),
        relative_path in any_relative_path(),
    ) {
        let path = format!("{task_folder}/{relative_path}");
        let lines = vec![edit_line(agent, &path)];

        let log_lines =
            describe_agent_log(agent, Path::new(&task_folder), &lines);

        let expected = normal_line(&format!("Edited {relative_path}"));
        prop_assert_eq!(log_lines, vec![expected]);
    }

    #[test]
    fn test_locate_task_folder_seen_by_agent_property_follows_the_sandbox(
        task_folder in any_task_folder(),
        sandbox in prop_oneof![
            Just(SandboxKind::LocalProcess),
            Just(SandboxKind::Container),
            Just(SandboxKind::MicroVirtualMachine),
        ],
    ) {
        let mounts = WorkspaceMounts {
            task_folder: PathBuf::from(&task_folder),
            git_directories: Vec::new(),
            placeholder_mounts: Vec::new(),
        };

        let seen_folder = locate_task_folder_seen_by_agent(sandbox, &mounts);

        let expected = match sandbox {
            SandboxKind::LocalProcess => PathBuf::from(&task_folder),
            SandboxKind::Container | SandboxKind::MicroVirtualMachine => {
                PathBuf::from(CONTAINER_WORKSPACE_DIRECTORY)
            }
        };
        prop_assert_eq!(seen_folder, expected);
    }
}

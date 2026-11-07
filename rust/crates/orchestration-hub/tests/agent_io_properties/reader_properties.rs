use std::path::PathBuf;

use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_output::AgentOutputReader;
use proptest::prelude::*;
use serde_json::json;

use crate::claude_lines::assistant_line;
use crate::codex_lines::{completed_line, file_change_item};
use crate::command_support::{ALL_AGENTS, any_agent};
use crate::gemini_lines::{finished_line, tool_use_line};
use crate::stream_support::{any_relative_path, read_agent_events};

const EDITED_VERB: &str = "Edited";
const CLAUDE_RESULT_LINE: &str =
    r#"{"type":"result","subtype":"success","is_error":false}"#;
const CODEX_FINISHED_LINE: &str = r#"{"type":"turn.completed"}"#;

fn any_task_folder() -> impl Strategy<Value = PathBuf> {
    "(/[a-z0-9é_-]{1,8}){1,3}".prop_map(PathBuf::from)
}

fn edit_line(agent: AgentKind, file_path: &str) -> String {
    match agent {
        AgentKind::ClaudeCode => assistant_line(&json!([{
            "type": "tool_use",
            "name": "Edit",
            "input": {"file_path": file_path},
        }])),
        AgentKind::Codex => completed_line(&file_change_item(
            &[(file_path.to_owned(), "update".to_owned())],
            "completed",
        )),
        AgentKind::GeminiCli => {
            tool_use_line("replace", &json!({"file_path": file_path}))
        }
    }
}

fn finish_line(agent: AgentKind) -> String {
    match agent {
        AgentKind::ClaudeCode => CLAUDE_RESULT_LINE.to_owned(),
        AgentKind::Codex => CODEX_FINISHED_LINE.to_owned(),
        AgentKind::GeminiCli => finished_line(),
    }
}

proptest! {
    #[test]
    fn test_agent_output_reader_new_property_equal_only_for_equal_inputs(
        first_agent in any_agent(),
        second_agent in any_agent(),
        first_folder in any_task_folder(),
        second_folder in any_task_folder(),
    ) {
        let first = AgentOutputReader::new(first_agent, &first_folder);
        let second = AgentOutputReader::new(second_agent, &second_folder);
        let same_as_first = AgentOutputReader::new(first_agent, &first_folder);

        let has_equal_inputs =
            first_agent == second_agent && first_folder == second_folder;
        prop_assert_eq!(first == second, has_equal_inputs);
        prop_assert_eq!(first, same_as_first);
    }

    #[test]
    fn test_agent_output_reader_new_property_task_folder_edits_read_alike(
        task_folder in any_task_folder(),
        relative_path in any_relative_path(),
    ) {
        let file_path = task_folder.join(&relative_path);
        let file_path = file_path.to_string_lossy();

        let expected = vec![AgentEvent::UsedTool(format!(
            "{EDITED_VERB} {relative_path}"
        ))];
        for agent in ALL_AGENTS {
            let lines = vec![edit_line(agent, &file_path)];
            let agent_events = read_agent_events(agent, &task_folder, &lines);
            prop_assert_eq!(&agent_events, &expected, "{:?}", agent);
        }
    }

    #[test]
    fn test_agent_output_reader_new_property_a_fresh_reader_holds_nothing(
        agent in any_agent(),
        task_folder in any_task_folder(),
    ) {
        let reader = AgentOutputReader::new(agent, &task_folder);

        let line = finish_line(agent);
        let (_next_reader, agent_events) = reader.read_line(&line);

        prop_assert_eq!(agent_events, vec![AgentEvent::Finished]);
    }
}

use std::path::Path;

use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::claude_lines::assistant_line;
use crate::codex_lines::{completed_line, file_change_item};
use crate::gemini_lines::{GeminiTool, known_gemini_tools, tool_use_line};
use crate::stream_support::{
    any_relative_path, any_tool_detail, read_agent_events,
    read_container_events, used_tool,
};

const LONGEST_DETAIL: usize = 100;
const SHORTENED_MARKER: char = '…';

fn any_gemini_tool() -> impl Strategy<Value = GeminiTool> {
    proptest::sample::select(known_gemini_tools())
}

fn any_task_folder() -> impl Strategy<Value = String> {
    "(/[a-z][a-z0-9_-]{0,8}){1,4}"
}

fn any_non_text_value() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(json!(7)),
        Just(json!(true)),
        Just(json!(null)),
        Just(json!(["a"])),
        Just(json!({"inner": "a"})),
    ]
}

fn web_search_line(query: &str) -> String {
    completed_line(
        &json!({"id": "item_5", "type": "web_search", "query": query}),
    )
}

fn edit_line(file_path: &str) -> String {
    let tool_use = json!({
        "type": "tool_use",
        "name": "Edit",
        "input": {"file_path": file_path, "old_string": "a"},
    });
    assistant_line(&json!([tool_use]))
}

fn read_edits(task_folder: &str, file_path: &str) -> Vec<AgentEvent> {
    let lines = vec![edit_line(file_path)];
    read_agent_events(AgentKind::ClaudeCode, Path::new(task_folder), &lines)
}

proptest! {
    #[test]
    fn test_describe_tool_use_property_known_tools_read_their_own_field(
        (tool_name, field, verb) in any_gemini_tool(),
        detail in any_tool_detail(),
        decoy in any_tool_detail(),
    ) {
        let parameters = json!({
            field: detail,
            "description": decoy,
            "other": decoy,
        });
        let lines = vec![tool_use_line(tool_name, &parameters)];

        let agent_events = read_container_events(AgentKind::GeminiCli, &lines);

        let expected = used_tool(&format!("{verb} {}", detail.trim()));
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_describe_tool_use_property_missing_text_names_the_tool(
        (tool_name, field, _verb) in any_gemini_tool(),
        value in prop_oneof![
            any_non_text_value(),
            "[ \t\n]{0,4}".prop_map(Value::from),
        ],
        is_missing in any::<bool>(),
    ) {
        let parameters = if is_missing {
            json!({"unrelated": "text"})
        } else {
            json!({ field: value })
        };
        let lines = vec![tool_use_line(tool_name, &parameters)];

        let agent_events = read_container_events(AgentKind::GeminiCli, &lines);

        prop_assert_eq!(
            agent_events,
            vec![used_tool(&format!("Used {tool_name}"))]
        );
    }

    #[test]
    fn test_describe_tool_use_property_unknown_tools_are_only_named(
        tool_name in "[a-z][a-z_]{0,20}",
        detail in any_tool_detail(),
    ) {
        let is_known = known_gemini_tools()
            .iter()
            .any(|(known_name, _, _)| *known_name == tool_name);
        prop_assume!(!is_known);
        let parameters = json!({"command": detail, "file_path": detail});
        let lines = vec![tool_use_line(&tool_name, &parameters)];

        let agent_events = read_container_events(AgentKind::GeminiCli, &lines);

        prop_assert_eq!(
            agent_events,
            vec![used_tool(&format!("Used {tool_name}"))]
        );
    }

    #[test]
    fn test_describe_tool_action_property_text_keeps_the_first_line_start(
        first_line in "[a-z][a-z0-9 ]{0,150}[a-z]",
        later_line in "[a-z]{1,10}",
    ) {
        let query = format!("  {first_line}\n{later_line}");
        let lines = vec![web_search_line(&query)];

        let agent_events = read_container_events(AgentKind::Codex, &lines);

        let Some(AgentEvent::UsedTool(description)) = agent_events.first()
        else {
            return Err(TestCaseError::fail(format!("{agent_events:?}")));
        };
        let shown = description
            .strip_prefix("Searched the web for ")
            .unwrap_or_default();
        let kept = shown.strip_suffix(SHORTENED_MARKER).unwrap_or(shown);
        prop_assert!(first_line.starts_with(kept), "{}", description);
        prop_assert!(kept.chars().count() <= LONGEST_DETAIL);
        prop_assert!(!description.contains('\n'));
    }

    #[test]
    fn test_describe_tool_action_property_blank_detail_names_the_tool(
        blank in "[ \t\n]{0,6}",
        kind in prop_oneof![Just("add"), Just("update"), Just("delete")],
    ) {
        let changes = vec![(blank.clone(), kind.to_owned())];
        let lines = vec![
            web_search_line(&blank),
            completed_line(&file_change_item(&changes, "completed")),
        ];

        let agent_events = read_container_events(AgentKind::Codex, &lines);

        let expected =
            vec![used_tool("Used web_search"), used_tool("Used apply_patch")];
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_describe_tool_action_property_file_paths_keep_their_end(
        relative_path in any_relative_path(),
        long_folder in "[a-z]{100,140}",
    ) {
        let path = format!("/elsewhere/{long_folder}/{relative_path}");
        let changes = vec![(path.clone(), "update".to_owned())];
        let lines =
            vec![completed_line(&file_change_item(&changes, "completed"))];

        let agent_events = read_container_events(AgentKind::Codex, &lines);

        let Some(AgentEvent::UsedTool(description)) = agent_events.first()
        else {
            return Err(TestCaseError::fail(format!("{agent_events:?}")));
        };
        let prefix = format!("Edited {SHORTENED_MARKER}");
        let kept = description.strip_prefix(&prefix).unwrap_or_default();
        prop_assert!(path.ends_with(kept), "{}", description);
        prop_assert_eq!(kept.chars().count(), LONGEST_DETAIL);
    }

    #[test]
    fn test_relative_to_task_folder_property_inside_paths_lose_the_folder(
        task_folder in any_task_folder(),
        relative_path in any_relative_path(),
        extra_separators in "/{0,3}",
    ) {
        let file_path =
            format!("{task_folder}/{extra_separators}{relative_path}");

        let agent_events = read_edits(&task_folder, &file_path);

        let expected = used_tool(&format!("Edited {relative_path}"));
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_relative_to_task_folder_property_lookalike_folders_stay_whole(
        task_folder in any_task_folder(),
        suffix in "[a-z0-9_-]{1,6}",
        relative_path in any_relative_path(),
    ) {
        let file_path = format!("{task_folder}{suffix}/{relative_path}");

        let agent_events = read_edits(&task_folder, &file_path);

        prop_assume!(file_path.chars().count() <= LONGEST_DETAIL);
        prop_assert_eq!(
            agent_events,
            vec![used_tool(&format!("Edited {file_path}"))]
        );
    }

    #[test]
    fn test_relative_to_task_folder_property_the_folder_itself_stays_whole(
        task_folder in any_task_folder(),
        ending in prop_oneof![Just(""), Just("/"), Just("//")],
    ) {
        let file_path = format!("{task_folder}{ending}");

        let agent_events = read_edits(&task_folder, &file_path);

        prop_assert_eq!(
            agent_events,
            vec![used_tool(&format!("Edited {file_path}"))]
        );
    }

    #[test]
    fn test_describe_file_path_property_only_the_first_line_is_a_path(
        relative_path in any_relative_path(),
        line_break in prop_oneof![Just('\n'), Just('\r'), Just('\u{2028}')],
        junk in "[a-z ]{1,20}",
    ) {
        let file_path =
            format!("/workspace/{relative_path}{line_break}{junk}");

        let agent_events = read_edits("/workspace", &file_path);

        let expected = used_tool(&format!("Edited {relative_path}"));
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_describe_file_path_property_shows_an_end_of_the_path(
        task_folder in any_task_folder(),
        file_path in "(/[a-zé中 ._-]{1,30}){1,8}",
    ) {
        let agent_events = read_edits(&task_folder, file_path.trim());

        let Some(AgentEvent::UsedTool(description)) = agent_events.first()
        else {
            return Err(TestCaseError::fail(format!("{agent_events:?}")));
        };
        let shown = description.strip_prefix("Edited ").unwrap_or_default();
        let kept = shown.strip_prefix(SHORTENED_MARKER).unwrap_or(shown);
        prop_assert!(file_path.trim().ends_with(kept), "{}", description);
        prop_assert!(kept.chars().count() <= LONGEST_DETAIL);
    }

    #[test]
    fn test_describe_file_path_property_blank_paths_name_the_tool(
        task_folder in any_task_folder(),
        blank in "[ \t\n\r]{0,6}",
    ) {
        let agent_events = read_edits(&task_folder, &blank);

        prop_assert_eq!(agent_events, vec![used_tool("Used Edit")]);
    }
}

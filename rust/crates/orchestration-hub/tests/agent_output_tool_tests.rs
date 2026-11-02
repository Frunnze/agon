mod claude_lines;

use claude_lines::{any_detail, assistant_line, parse_claude};
use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;
use serde_json::{Value, json};

type KnownTool = (&'static str, &'static str, &'static str);

const MAXIMUM_DETAIL_CHARACTERS: usize = 100;

const FILE_TOOLS: [KnownTool; 5] = [
    ("Edit", "file_path", "Edited"),
    ("MultiEdit", "file_path", "Edited"),
    ("NotebookEdit", "notebook_path", "Edited"),
    ("Write", "file_path", "Wrote"),
    ("Read", "file_path", "Read"),
];

const TEXT_TOOLS: [KnownTool; 5] = [
    ("Bash", "command", "Ran"),
    ("Grep", "pattern", "Searched for"),
    ("Glob", "pattern", "Looked for files matching"),
    ("WebFetch", "url", "Fetched"),
    ("WebSearch", "query", "Searched the web for"),
];

fn known_tools() -> Vec<KnownTool> {
    let mut tools = FILE_TOOLS.to_vec();
    tools.extend(TEXT_TOOLS);
    tools
}

fn any_known_tool() -> impl Strategy<Value = KnownTool> {
    proptest::sample::select(known_tools())
}

fn any_file_tool() -> impl Strategy<Value = KnownTool> {
    proptest::sample::select(FILE_TOOLS.to_vec())
}

fn any_text_tool() -> impl Strategy<Value = KnownTool> {
    proptest::sample::select(TEXT_TOOLS.to_vec())
}

fn any_relative_path() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9_.-]{1,12}(/[a-zA-Z0-9_.-]{1,12}){0,4}"
}

fn any_path_outside_the_workspace() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("/workspace".to_string()),
        Just("/workspace/".to_string()),
        "/workspaces/[a-z]{1,8}",
        "/tmp/workspace/[a-z]{1,8}",
        "/(home|Users)/[a-z]{1,8}(/[a-z.]{1,8}){0,3}",
        "workspace/[a-z]{1,8}",
    ]
}

fn tool_use_line(tool: &str, input: &Value) -> String {
    assistant_line(&json!([
        {"type": "tool_use", "id": "toolu_01", "name": tool, "input": input}
    ]))
}

fn used_tool(description: &str) -> Vec<AgentEvent> {
    vec![AgentEvent::UsedTool(description.to_string())]
}

proptest! {
    #[test]
    fn test_parse_agent_line_property_known_tools_are_described(
        (tool, field, verb) in any_known_tool(),
        detail in any_detail(),
    ) {
        prop_assume!(!detail.starts_with("/workspace/"));
        let line = tool_use_line(tool, &json!({ field: detail }));

        let events = parse_claude(&line);

        prop_assert_eq!(events, used_tool(&format!("{verb} {detail}")));
    }

    #[test]
    fn test_parse_agent_line_property_workspace_paths_become_relative(
        (tool, field, verb) in any_file_tool(),
        relative_path in any_relative_path(),
    ) {
        let path = format!("/workspace/{relative_path}");
        let line = tool_use_line(tool, &json!({ field: path }));

        let events = parse_claude(&line);

        let expected = used_tool(&format!("{verb} {relative_path}"));
        prop_assert_eq!(events, expected);
    }

    #[test]
    fn test_parse_agent_line_property_outside_paths_stay_as_given(
        (tool, field, verb) in any_file_tool(),
        path in any_path_outside_the_workspace(),
    ) {
        let line = tool_use_line(tool, &json!({ field: path }));

        let events = parse_claude(&line);

        prop_assert_eq!(events, used_tool(&format!("{verb} {path}")));
    }

    #[test]
    fn test_parse_agent_line_property_text_details_keep_workspace_prefix(
        (tool, field, verb) in any_text_tool(),
        relative_path in any_relative_path(),
    ) {
        let detail = format!("/workspace/{relative_path}");
        let line = tool_use_line(tool, &json!({ field: detail }));

        let events = parse_claude(&line);

        prop_assert_eq!(events, used_tool(&format!("{verb} {detail}")));
    }

    #[test]
    fn test_parse_agent_line_property_only_the_first_line_is_described(
        lines in proptest::collection::vec("[a-z][a-z ]{0,20}[a-z]", 2..5),
    ) {
        let command = lines.join("\n");
        let line = tool_use_line("Bash", &json!({"command": command}));

        let events = parse_claude(&line);

        prop_assert_eq!(events, used_tool(&format!("Ran {}", lines[0])));
    }

    #[test]
    fn test_parse_agent_line_property_long_details_are_shortened(
        (tool, field, verb) in any_known_tool(),
        detail in "[a-z][a-z /]{120,300}[a-z]",
    ) {
        let line = tool_use_line(tool, &json!({ field: detail }));

        let events = parse_claude(&line);

        let description = match events.as_slice() {
            [AgentEvent::UsedTool(description)] => description.clone(),
            _ => return Err(TestCaseError::fail("expected one tool event")),
        };
        let prefix = format!("{verb} ");
        let shortened = description
            .strip_prefix(&prefix)
            .and_then(|rest| rest.strip_suffix('…'))
            .unwrap_or_default();
        let shortened_length = shortened.chars().count();
        prop_assert!(!shortened.is_empty());
        prop_assert!(shortened_length <= MAXIMUM_DETAIL_CHARACTERS);
        prop_assert!(detail.starts_with(shortened));
    }

    #[test]
    fn test_parse_agent_line_property_other_tools_are_named(
        tool in "[a-zA-Z_][a-zA-Z0-9_]{0,30}",
        input in prop_oneof![Just(json!({})), Just(json!({"x": 1}))],
    ) {
        let known_names: Vec<&str> =
            known_tools().iter().map(|(name, _, _)| *name).collect();
        prop_assume!(!known_names.contains(&tool.as_str()));

        let events = parse_claude(&tool_use_line(&tool, &input));

        prop_assert_eq!(events, used_tool(&format!("Used {tool}")));
    }

    #[test]
    fn test_parse_agent_line_property_known_tool_without_detail_is_named(
        (tool, _field, _verb) in any_known_tool(),
    ) {
        let events = parse_claude(&tool_use_line(tool, &json!({})));

        prop_assert_eq!(events, used_tool(&format!("Used {tool}")));
    }
}

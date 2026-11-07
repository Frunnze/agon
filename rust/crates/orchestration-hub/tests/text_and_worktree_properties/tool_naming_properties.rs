use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::agent_reading::parse_agent_line;
use crate::claude_lines::assistant_line;
use crate::codex_lines::{completed_line, started_line, tool_call_item};
use crate::stream_support::{any_relative_path, any_tool_detail, used_tool};

type ClaudeTool = (&'static str, &'static str, &'static str, bool);

const LONGEST_DETAIL: usize = 100;
const SHORTENED_MARKER: char = '…';
const UNNAMED_TOOL: &str = "Used a tool";
const SURVIVING_LINE_BREAKS: [char; 4] = ['\n', '\r', '\u{2028}', '\u{2029}'];
const CLAUDE_TOOLS: [ClaudeTool; 10] = [
    ("Bash", "command", "Ran", false),
    ("Edit", "file_path", "Edited", true),
    ("MultiEdit", "file_path", "Edited", true),
    ("NotebookEdit", "notebook_path", "Edited", true),
    ("Write", "file_path", "Wrote", true),
    ("Read", "file_path", "Read", true),
    ("Grep", "pattern", "Searched for", false),
    ("Glob", "pattern", "Looked for files matching", false),
    ("WebFetch", "url", "Fetched", false),
    ("WebSearch", "query", "Searched the web for", false),
];

fn any_claude_tool() -> impl Strategy<Value = ClaudeTool> {
    proptest::sample::select(CLAUDE_TOOLS.to_vec())
}

fn any_line_break() -> impl Strategy<Value = char> {
    proptest::sample::select(SURVIVING_LINE_BREAKS.to_vec())
}

fn describe_claude_tool(tool_name: &str, input: &Value) -> Vec<AgentEvent> {
    let tool_use =
        json!({"type": "tool_use", "name": tool_name, "input": input});
    parse_agent_line(
        AgentKind::ClaudeCode,
        &assistant_line(&json!([tool_use])),
    )
}

fn name_codex_tool(tool: &str) -> Vec<AgentEvent> {
    let line = started_line(&tool_call_item(tool, "in_progress", None));
    parse_agent_line(AgentKind::Codex, &line)
}

fn search_codex_web(query: &str) -> Vec<AgentEvent> {
    let item = json!({"id": "item_5", "type": "web_search", "query": query});
    parse_agent_line(AgentKind::Codex, &completed_line(&item))
}

proptest! {
    #[test]
    fn test_define_known_tool_property_every_tool_keeps_its_verb(
        (tool_name, field, verb, _is_file) in any_claude_tool(),
        detail in any_tool_detail(),
    ) {
        let outside_detail = format!("/elsewhere/{detail}");
        let input = json!({ field: outside_detail });

        let agent_events = describe_claude_tool(tool_name, &input);

        let expected = format!("{verb} {}", outside_detail.trim());
        prop_assert_eq!(agent_events, vec![used_tool(&expected)]);
    }

    #[test]
    fn test_define_known_tool_property_every_tool_reads_only_its_field(
        (tool_name, field, _verb, _is_file) in any_claude_tool(),
        (_other_name, other_field, _other_verb, _other_is_file) in
            any_claude_tool(),
        detail in any_tool_detail(),
    ) {
        prop_assume!(field != other_field);
        let input = json!({ other_field: detail });

        let agent_events = describe_claude_tool(tool_name, &input);

        prop_assert_eq!(
            agent_events,
            vec![used_tool(&format!("Used {tool_name}"))]
        );
    }

    #[test]
    fn test_define_known_tool_property_only_file_tools_shorten_task_paths(
        (tool_name, field, verb, is_file) in any_claude_tool(),
        relative_path in any_relative_path(),
    ) {
        let path = format!("{CONTAINER_WORKSPACE_DIRECTORY}/{relative_path}");
        let input = json!({ field: path });

        let agent_events = describe_claude_tool(tool_name, &input);

        let shown = if is_file { relative_path } else { path };
        prop_assert_eq!(
            agent_events,
            vec![used_tool(&format!("{verb} {shown}"))]
        );
    }

    #[test]
    fn test_name_tool_property_blank_names_are_an_unnamed_tool(
        blank in "[ \t\n\r]{0,6}",
    ) {
        prop_assert_eq!(
            name_codex_tool(&blank),
            vec![used_tool(UNNAMED_TOOL)]
        );
        prop_assert_eq!(
            describe_claude_tool(&blank, &json!({})),
            vec![used_tool(UNNAMED_TOOL)]
        );
    }

    #[test]
    fn test_name_tool_property_only_the_first_line_names_the_tool(
        name in "[a-z][a-z_.]{0,20}",
        line_break in any_line_break(),
        rest in "[a-z ]{1,20}",
    ) {
        let tool = format!(" \n {name} {line_break}{rest}");

        prop_assert_eq!(
            name_codex_tool(&tool),
            vec![used_tool(&format!("Used {name}"))]
        );
    }

    #[test]
    fn test_name_tool_property_long_names_keep_their_start(
        name in "[a-z][a-z_]{100,160}",
    ) {
        let agent_events = name_codex_tool(&name);

        let Some(AgentEvent::UsedTool(description)) = agent_events.first()
        else {
            return Err(TestCaseError::fail(format!("{agent_events:?}")));
        };
        let shown = description.strip_prefix("Used ").unwrap_or_default();
        let kept = shown.strip_suffix(SHORTENED_MARKER).unwrap_or_default();
        prop_assert!(name.starts_with(kept), "{}", description);
        prop_assert_eq!(kept.chars().count(), LONGEST_DETAIL);
    }

    #[test]
    fn test_read_first_line_property_leading_blank_lines_are_skipped(
        blank_lines in "([ \t]{0,3}\n){1,4}",
        first in "[a-z][a-z ]{0,20}[a-z]",
        second in "[a-z]{1,10}",
    ) {
        let query = format!("{blank_lines}{first}\n{second}");

        let expected = used_tool(&format!("Searched the web for {first}"));
        prop_assert_eq!(search_codex_web(&query), vec![expected]);
    }

    #[test]
    fn test_read_first_line_property_surrounding_spaces_are_trimmed(
        before in "[ \t\u{a0}\u{3000}]{0,4}",
        query in "[a-z][a-z ]{0,20}[a-z]",
        after in "[ \t\u{a0}\u{3000}]{0,4}",
    ) {
        let spaced = format!("{before}{query}{after}");

        let expected = used_tool(&format!("Searched the web for {query}"));
        prop_assert_eq!(search_codex_web(&spaced), vec![expected]);
    }

    #[test]
    fn test_read_first_line_property_any_line_break_ends_the_line(
        first in "[a-z][a-z ]{0,20}[a-z]",
        line_break in any_line_break(),
        second in "[a-z]{1,10}",
    ) {
        let query = format!("{first}{line_break}{second}");

        let expected = used_tool(&format!("Searched the web for {first}"));
        prop_assert_eq!(search_codex_web(&query), vec![expected]);
    }
}

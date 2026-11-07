use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::agent_reading::parse_agent_line;
use crate::codex_lines::{
    agent_message, command_item, completed_line, file_change_item,
    started_line, tool_call_item,
};
use crate::stream_support::{
    UNKNOWN_AGENT_ERROR, any_tool_detail, expect_given_text,
};

const SHELL_WRAPPERS: [&str; 4] =
    ["bash -lc", "/bin/bash -lc", "/bin/zsh -lc", "sh -lc"];
const BLANK_TEXTS: [&str; 5] = ["", " ", "\t\n", "\u{a0}\u{3000}", "\r\n "];

fn parse_codex(line: &str) -> Vec<AgentEvent> {
    parse_agent_line(AgentKind::Codex, line)
}

fn any_blank_text() -> impl Strategy<Value = &'static str> {
    proptest::sample::select(BLANK_TEXTS.to_vec())
}

fn web_search_item(query: &str) -> Value {
    json!({"id": "item_5", "type": "web_search", "query": query})
}

fn any_tool_item() -> impl Strategy<Value = Value> {
    prop_oneof![
        any_tool_detail().prop_map(|command| command_item(
            &command,
            "completed",
            ""
        )),
        "[a-z_]{1,12}".prop_map(|tool| tool_call_item(
            &tool,
            "completed",
            None
        )),
        any_tool_detail().prop_map(|query| web_search_item(&query)),
        "[a-z]{1,8}\\.rs".prop_map(|path| {
            file_change_item(&[(path, "update".to_owned())], "completed")
        }),
    ]
}

fn count_used_tools(agent_events: &[AgentEvent]) -> usize {
    agent_events
        .iter()
        .filter(|agent_event| matches!(agent_event, AgentEvent::UsedTool(_)))
        .count()
}

proptest! {
    #[test]
    fn test_describe_started_item_property_commands_are_ran(
        command in any_tool_detail(),
        wrapper in proptest::sample::select(SHELL_WRAPPERS.to_vec()),
    ) {
        let wrapped = format!("{wrapper} '{command}'");
        let item = command_item(&wrapped, "in_progress", "");

        let agent_events = parse_codex(&started_line(&item));

        let expected = AgentEvent::UsedTool(format!("Ran {command}"));
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_describe_started_item_property_tool_calls_name_the_tool(
        tool in "[a-z_]{1,16}",
        blank in any_blank_text(),
    ) {
        let named = tool_call_item(&tool, "in_progress", None);
        let unnamed = tool_call_item(blank, "in_progress", None);

        let named_events = parse_codex(&started_line(&named));
        let unnamed_events = parse_codex(&started_line(&unnamed));

        let expected = AgentEvent::UsedTool(format!("Used {tool}"));
        prop_assert_eq!(named_events, vec![expected]);
        let unnamed_tool = AgentEvent::UsedTool("Used a tool".to_owned());
        prop_assert_eq!(unnamed_events, vec![unnamed_tool]);
    }

    #[test]
    fn test_describe_started_item_property_each_tool_is_described_once(
        item in any_tool_item(),
    ) {
        let mut agent_events = parse_codex(&started_line(&item));
        agent_events.extend(parse_codex(&completed_line(&item)));

        prop_assert_eq!(count_used_tools(&agent_events), 1);
        prop_assert_eq!(agent_events.len(), 1);
    }

    #[test]
    fn test_describe_completed_item_property_web_searches_name_the_query(
        query in any_tool_detail(),
        blank in any_blank_text(),
    ) {
        let searched = parse_codex(&completed_line(&web_search_item(&query)));
        let unclear = parse_codex(&completed_line(&web_search_item(blank)));

        let expected = format!("Searched the web for {query}");
        prop_assert_eq!(searched, vec![AgentEvent::UsedTool(expected)]);
        let unnamed = AgentEvent::UsedTool("Used web_search".to_owned());
        prop_assert_eq!(unclear, vec![unnamed]);
    }

    #[test]
    fn test_describe_completed_item_property_error_items_are_failures(
        message in any::<String>(),
    ) {
        let item =
            json!({"id": "item_6", "type": "error", "message": message});

        let agent_events = parse_codex(&completed_line(&item));

        let error = expect_given_text(&message, UNKNOWN_AGENT_ERROR);
        prop_assert_eq!(agent_events, vec![AgentEvent::ToolFailed(error)]);
    }

    #[test]
    fn test_describe_completed_item_property_other_items_give_nothing(
        item_type in "[a-z_]{1,16}",
        text in any::<String>(),
    ) {
        let known_types = [
            "agent_message", "command_execution", "file_change",
            "mcp_tool_call", "web_search", "error",
        ];
        prop_assume!(!known_types.contains(&item_type.as_str()));
        let item = json!({"id": "item_7", "type": item_type, "text": text});

        prop_assert_eq!(parse_codex(&started_line(&item)), Vec::new());
        prop_assert_eq!(parse_codex(&completed_line(&item)), Vec::new());
    }

    #[test]
    fn test_describe_agent_message_property_said_text_is_trimmed(
        text in any::<String>(),
        padding in "[ \n\t\r]{0,3}",
    ) {
        prop_assume!(!text.trim().is_empty());
        let padded = format!("{padding}{text}{padding}");

        let line = completed_line(&agent_message(&padded));
        let agent_events = parse_codex(&line);

        let expected = AgentEvent::Said(text.trim().to_owned());
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_describe_agent_message_property_blank_messages_say_nothing(
        blank in any_blank_text(),
    ) {
        let started = parse_codex(&started_line(&agent_message("hello")));
        let completed = parse_codex(&completed_line(&agent_message(blank)));

        prop_assert_eq!(started, Vec::new());
        prop_assert_eq!(completed, Vec::new());
    }

    #[test]
    fn test_describe_agent_message_property_inner_lines_are_kept(
        lines in proptest::collection::vec("[a-zé中 ]{0,12}[a-z]", 1..5),
        separator in "\n{1,2}|\r\n",
    ) {
        let text = lines.join(&separator);

        let agent_events = parse_codex(&completed_line(&agent_message(&text)));

        let expected = AgentEvent::Said(text.trim().to_owned());
        prop_assert_eq!(agent_events, vec![expected]);
    }
}

use std::path::Path;

use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::agent_log_lines::{any_stream_json_line, init_line};
use crate::claude_lines::{assistant_line, parse_claude};
use crate::stream_support::{
    any_relative_path, any_tool_detail, read_agent_events,
};

const KNOWN_EVENT_TYPES: [&str; 4] = ["system", "assistant", "user", "result"];
const BLANK_TEXTS: [&str; 5] = ["", " ", "\t\n", "\u{a0}\u{3000}", "\r\n "];
const LARGEST_BLOCK_COUNT: usize = 6;

type ClaudeTool = (&'static str, &'static str, &'static str);

const TEXT_TOOLS: [ClaudeTool; 5] = [
    ("Bash", "command", "Ran"),
    ("Grep", "pattern", "Searched for"),
    ("Glob", "pattern", "Looked for files matching"),
    ("WebFetch", "url", "Fetched"),
    ("WebSearch", "query", "Searched the web for"),
];
const FILE_TOOLS: [ClaudeTool; 5] = [
    ("Edit", "file_path", "Edited"),
    ("MultiEdit", "file_path", "Edited"),
    ("NotebookEdit", "notebook_path", "Edited"),
    ("Write", "file_path", "Wrote"),
    ("Read", "file_path", "Read"),
];

#[derive(Clone, Debug)]
enum ContentBlock {
    Text(String),
    UnknownTool(String),
    Thinking(String),
}

fn any_content_block() -> impl Strategy<Value = ContentBlock> {
    prop_oneof![
        any::<String>().prop_map(ContentBlock::Text),
        proptest::sample::select(BLANK_TEXTS.to_vec())
            .prop_map(|text| ContentBlock::Text(text.to_owned())),
        "mcp__[a-z]{1,8}__[a-z_]{1,8}".prop_map(ContentBlock::UnknownTool),
        any::<String>().prop_map(ContentBlock::Thinking),
    ]
}

fn render_block(block: &ContentBlock) -> Value {
    match block {
        ContentBlock::Text(text) => json!({"type": "text", "text": text}),
        ContentBlock::UnknownTool(name) => {
            json!({"type": "tool_use", "id": "toolu_1", "name": name})
        }
        ContentBlock::Thinking(thought) => {
            json!({"type": "thinking", "thinking": thought})
        }
    }
}

fn describe_block(block: &ContentBlock) -> Option<AgentEvent> {
    match block {
        ContentBlock::Text(text) if !text.trim().is_empty() => {
            Some(AgentEvent::Said(text.trim().to_owned()))
        }
        ContentBlock::UnknownTool(name) => {
            Some(AgentEvent::UsedTool(format!("Used {name}")))
        }
        ContentBlock::Text(_) | ContentBlock::Thinking(_) => None,
    }
}

fn tool_use_line(tool_name: &str, field: &str, detail: &str) -> String {
    let mut input = json!({});
    input[field] = json!(detail);
    let tool_use =
        json!({"type": "tool_use", "name": tool_name, "input": input});
    assistant_line(&json!([tool_use]))
}

fn system_line(subtype: Option<&str>, session: &Value) -> String {
    json!({"type": "system", "subtype": subtype, "session_id": session})
        .to_string()
}

fn any_other_event_type() -> impl Strategy<Value = String> {
    "[a-z_.]{1,16}".prop_filter("an unknown type", |event_type| {
        !KNOWN_EVENT_TYPES.contains(&event_type.as_str())
    })
}

proptest! {
    #[test]
    fn test_parse_claude_line_property_unknown_event_types_give_nothing(
        event_type in any_other_event_type(),
        text in any::<String>(),
    ) {
        let line = json!({"type": event_type, "text": text, "result": text});

        prop_assert_eq!(parse_claude(&line.to_string()), Vec::new());
    }

    #[test]
    fn test_parse_claude_line_property_lines_are_read_independently(
        lines in vec(any_stream_json_line(), 0..LARGEST_BLOCK_COUNT),
    ) {
        let task_folder = Path::new(CONTAINER_WORKSPACE_DIRECTORY);

        let agent = AgentKind::ClaudeCode;
        let together = read_agent_events(agent, task_folder, &lines);

        let mut one_by_one = Vec::new();
        for line in &lines {
            one_by_one.extend(parse_claude(line));
        }
        prop_assert_eq!(together, one_by_one);
    }

    #[test]
    fn test_parse_claude_line_property_trailing_line_ends_never_matter(
        line in any_stream_json_line(),
        line_end in "[ \t\r]{1,4}",
    ) {
        let padded = format!("{line}{line_end}");

        prop_assert_eq!(parse_claude(&padded), parse_claude(&line));
    }

    #[test]
    fn test_describe_system_event_property_init_keeps_the_session(
        session in any::<String>(),
    ) {
        prop_assume!(!session.trim().is_empty());

        let agent_events = parse_claude(&init_line(&session));

        let expected = AgentEvent::SessionStarted(session);
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_describe_system_event_property_blank_sessions_start_nothing(
        blank in proptest::sample::select(BLANK_TEXTS.to_vec()),
    ) {
        let blank_line = system_line(Some("init"), &json!(blank));
        let null_line = system_line(Some("init"), &Value::Null);

        prop_assert_eq!(parse_claude(&blank_line), Vec::new());
        prop_assert_eq!(parse_claude(&null_line), Vec::new());
    }

    #[test]
    fn test_describe_system_event_property_other_subtypes_start_nothing(
        subtype in "[a-z_]{1,16}",
        session in "[a-f0-9-]{1,36}",
    ) {
        prop_assume!(subtype != "init");

        let other_line = system_line(Some(&subtype), &json!(session));
        let untyped_line = system_line(None, &json!(session));

        prop_assert_eq!(parse_claude(&other_line), Vec::new());
        prop_assert_eq!(parse_claude(&untyped_line), Vec::new());
    }

    #[test]
    fn test_describe_message_property_keeps_the_order_of_blocks(
        blocks in vec(any_content_block(), 0..LARGEST_BLOCK_COUNT),
    ) {
        let content: Vec<Value> = blocks.iter().map(render_block).collect();

        let agent_events = parse_claude(&assistant_line(&json!(content)));

        let expected: Vec<AgentEvent> =
            blocks.iter().filter_map(describe_block).collect();
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_describe_message_property_text_tools_name_their_detail(
        tool in proptest::sample::select(TEXT_TOOLS.to_vec()),
        detail in any_tool_detail(),
    ) {
        let (tool_name, field, verb) = tool;

        let line = tool_use_line(tool_name, field, &detail);
        let agent_events = parse_claude(&line);

        let expected = AgentEvent::UsedTool(format!("{verb} {detail}"));
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_describe_message_property_file_tools_show_relative_paths(
        tool in proptest::sample::select(FILE_TOOLS.to_vec()),
        relative_path in any_relative_path(),
    ) {
        let (tool_name, field, verb) = tool;
        let workspace = CONTAINER_WORKSPACE_DIRECTORY;
        let file_path = format!("{workspace}/{relative_path}");

        let line = tool_use_line(tool_name, field, &file_path);
        let agent_events = parse_claude(&line);

        let expected = AgentEvent::UsedTool(format!("{verb} {relative_path}"));
        prop_assert_eq!(agent_events, vec![expected]);
    }
}

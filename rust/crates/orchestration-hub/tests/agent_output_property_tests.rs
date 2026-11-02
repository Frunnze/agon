mod claude_lines;

use claude_lines::{any_detail, assistant_line, parse_claude};
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_output::parse_agent_line;
use proptest::prelude::*;
use serde_json::{Value, json};

#[derive(Clone, Debug)]
enum ContentBlock {
    Text(String),
    BashCommand(String),
    Thinking(String),
}

fn any_agent() -> impl Strategy<Value = AgentKind> {
    prop_oneof![
        Just(AgentKind::ClaudeCode),
        Just(AgentKind::Codex),
        Just(AgentKind::GeminiCli),
    ]
}

fn any_content_block() -> impl Strategy<Value = ContentBlock> {
    prop_oneof![
        any::<String>().prop_map(ContentBlock::Text),
        any_detail().prop_map(ContentBlock::BashCommand),
        any::<String>().prop_map(ContentBlock::Thinking),
    ]
}

fn any_non_blank_text() -> impl Strategy<Value = String> {
    any::<String>()
        .prop_filter("text has content", |text| !text.trim().is_empty())
}

fn is_json_object(text: &str) -> bool {
    serde_json::from_str::<Value>(text).is_ok_and(|value| value.is_object())
}

fn any_other_event_type() -> impl Strategy<Value = String> {
    "[a-z_]{1,12}".prop_filter("not a mapped type", |name| {
        !["system", "assistant", "result"].contains(&name.as_str())
    })
}

proptest! {
    #[test]
    fn test_parse_agent_line_property_blank_lines_give_no_events(
        agent in any_agent(),
        line in "[ \t\r\n]{0,10}",
    ) {
        prop_assert_eq!(parse_agent_line(agent, &line), Vec::new());
    }

    #[test]
    fn test_parse_agent_line_property_plain_text_is_said(
        agent in any_agent(),
        line in any_non_blank_text(),
    ) {
        prop_assume!(!is_json_object(&line));

        let events = parse_agent_line(agent, &line);

        let expected = AgentEvent::Said(line.trim_end().to_string());
        prop_assert_eq!(events, vec![expected]);
    }

    #[test]
    fn test_parse_agent_line_property_codex_and_gemini_lines_are_said(
        agent in prop_oneof![
            Just(AgentKind::Codex),
            Just(AgentKind::GeminiCli),
        ],
        line in prop_oneof![
            any_non_blank_text(),
            Just(r#"{"type":"result","subtype":"success"}"#.to_string()),
        ],
    ) {
        let events = parse_agent_line(agent, &line);

        let expected = AgentEvent::Said(line.trim_end().to_string());
        prop_assert_eq!(events, vec![expected]);
    }

    #[test]
    fn test_parse_agent_line_property_init_event_starts_session(
        session in any_non_blank_text(),
        model in "[a-z0-9-]{1,30}",
    ) {
        let line = json!({
            "type": "system",
            "subtype": "init",
            "cwd": "/workspace",
            "session_id": session,
            "tools": ["Bash", "Edit"],
            "model": model,
        })
        .to_string();

        let events = parse_claude(&line);

        prop_assert_eq!(events, vec![AgentEvent::SessionStarted(session)]);
    }

    #[test]
    fn test_parse_agent_line_property_assistant_blocks_map_in_order(
        blocks in proptest::collection::vec(any_content_block(), 0..6),
    ) {
        let mut content = Vec::new();
        let mut expected = Vec::new();
        for block in &blocks {
            match block {
                ContentBlock::Text(text) => {
                    content.push(json!({"type": "text", "text": text}));
                    if !text.trim().is_empty() {
                        expected.push(AgentEvent::Said(text.trim().into()));
                    }
                }
                ContentBlock::BashCommand(command) => {
                    content.push(json!({
                        "type": "tool_use",
                        "name": "Bash",
                        "input": {"command": command},
                    }));
                    let description = format!("Ran {command}");
                    expected.push(AgentEvent::UsedTool(description));
                }
                ContentBlock::Thinking(thinking) => {
                    content.push(json!({
                        "type": "thinking",
                        "thinking": thinking,
                    }));
                }
            }
        }

        let events = parse_claude(&assistant_line(&Value::Array(content)));

        prop_assert_eq!(events, expected);
    }

    #[test]
    fn test_parse_agent_line_property_successful_result_finishes(
        result_text in any::<String>(),
        turns in 0_u32..100,
        error_field in prop_oneof![Just(Some(false)), Just(None)],
    ) {
        let mut result = json!({
            "type": "result",
            "subtype": "success",
            "result": result_text,
            "num_turns": turns,
        });
        if let Some(is_error) = error_field {
            result["is_error"] = json!(is_error);
        }

        let events = parse_claude(&result.to_string());

        prop_assert_eq!(events, vec![AgentEvent::Finished]);
    }

    #[test]
    fn test_parse_agent_line_property_error_result_fails_with_a_reason(
        subtype in prop_oneof![
            Just("error_max_turns"),
            Just("error_during_execution"),
            Just("success"),
        ],
        result_text in proptest::option::of(any::<String>()),
    ) {
        let mut result = json!({
            "type": "result",
            "subtype": subtype,
            "is_error": true,
        });
        if let Some(text) = &result_text {
            result["result"] = json!(text);
        }
        let given_reason = result_text
            .as_deref()
            .map(str::trim)
            .filter(|text| !text.is_empty());
        let subtype_reason = Some(subtype).filter(|name| *name != "success");
        let expected_reason = given_reason
            .or(subtype_reason)
            .unwrap_or("the agent stopped with an error");

        let events = parse_claude(&result.to_string());

        let expected = AgentEvent::Failed(expected_reason.to_string());
        prop_assert_eq!(events, vec![expected]);
    }

    #[test]
    fn test_parse_agent_line_property_other_events_give_nothing(
        event_type in prop_oneof![
            Just("user".to_string()),
            Just("stream_event".to_string()),
            any_other_event_type(),
        ],
        payload in any::<String>(),
    ) {
        let line =
            json!({"type": event_type, "payload": payload}).to_string();

        prop_assert_eq!(parse_claude(&line), Vec::new());
    }

    #[test]
    fn test_parse_agent_line_property_other_system_events_give_nothing(
        subtype in "[a-z_]{1,16}".prop_filter("not init", |name| {
            name != "init"
        }),
    ) {
        let line = json!({
            "type": "system",
            "subtype": subtype,
            "session_id": "5f0c3e2a",
        })
        .to_string();

        prop_assert_eq!(parse_claude(&line), Vec::new());
    }
}

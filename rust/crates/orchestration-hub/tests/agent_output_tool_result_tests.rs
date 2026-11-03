mod agent_reading;

mod claude_tool_results;

use agent_reading::parse_agent_line;
use claude_tool_results::{
    ToolOutcome, ToolResultContent, any_tool_result_content,
    read_tool_result_text, render_tool_result_content, tool_result_line,
    user_line,
};
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;
use serde_json::{Value, json};

const UNKNOWN_TOOL_FAILURE: &str = "the tool failed";

fn describe_expected_failure(content: &ToolResultContent) -> AgentEvent {
    let error_text = read_tool_result_text(content);
    if error_text.is_empty() {
        return AgentEvent::ToolFailed(UNKNOWN_TOOL_FAILURE.to_string());
    }
    AgentEvent::ToolFailed(error_text)
}

fn parse_claude(line: &str) -> Vec<AgentEvent> {
    parse_agent_line(AgentKind::ClaudeCode, line)
}

proptest! {
    #[test]
    fn test_parse_agent_line_property_failed_tool_results_report_errors(
        results in proptest::collection::vec(
            (proptest::option::of(any::<bool>()), any_tool_result_content()),
            0..5,
        ),
    ) {
        let mut blocks = Vec::new();
        let mut expected = Vec::new();
        for (is_error, content) in &results {
            let mut block = json!({
                "type": "tool_result",
                "tool_use_id": "toolu_01",
                "content": render_tool_result_content(content),
            });
            if let Some(is_error) = is_error {
                block["is_error"] = json!(is_error);
            }
            blocks.push(block);
            if *is_error == Some(true) {
                expected.push(describe_expected_failure(content));
            }
        }

        let events = parse_claude(&user_line(&Value::Array(blocks)));

        prop_assert_eq!(events, expected);
    }

    #[test]
    fn test_parse_agent_line_property_one_failed_tool_gives_one_failure(
        content in any_tool_result_content(),
    ) {
        let failed =
            parse_claude(&tool_result_line(&content, ToolOutcome::Failed));
        let succeeded =
            parse_claude(&tool_result_line(&content, ToolOutcome::Succeeded));

        prop_assert_eq!(failed, vec![describe_expected_failure(&content)]);
        prop_assert_eq!(succeeded, Vec::new());
    }

    #[test]
    fn test_parse_agent_line_property_user_prompts_give_nothing(
        prompt in any::<String>(),
    ) {
        let events = parse_claude(&user_line(&json!(prompt)));

        prop_assert_eq!(events, Vec::new());
    }

    #[test]
    fn test_parse_agent_line_property_other_user_blocks_give_nothing(
        block_type in "[a-z_]{1,12}".prop_filter(
            "not a tool result",
            |name| name != "tool_result",
        ),
        text in any::<String>(),
    ) {
        let block =
            json!({"type": block_type, "text": text, "is_error": true});

        let events = parse_claude(&user_line(&Value::Array(vec![block])));

        prop_assert_eq!(events, Vec::new());
    }
}

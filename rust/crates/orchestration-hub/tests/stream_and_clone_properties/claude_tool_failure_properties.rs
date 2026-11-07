use orchestration_hub::agent_event::AgentEvent;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::claude_lines::parse_claude;
use crate::claude_tool_results::{
    ToolOutcome, ToolResultContent, any_tool_result_content,
    read_tool_result_text, render_tool_result_content, tool_result_line,
    user_line,
};
use crate::stream_support::{UNKNOWN_TOOL_FAILURE, expect_given_text};

const LARGEST_BLOCK_COUNT: usize = 6;

#[derive(Clone, Debug)]
struct ResultBlock {
    block_type: &'static str,
    is_error: Value,
    content: ToolResultContent,
}

fn any_is_error() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(json!(true)),
        Just(json!(false)),
        Just(Value::Null),
        Just(json!("true")),
        Just(json!(1)),
    ]
}

fn any_result_block() -> impl Strategy<Value = ResultBlock> {
    let block_type = prop_oneof![Just("tool_result"), Just("text")];
    (block_type, any_is_error(), any_tool_result_content()).prop_map(
        |(block_type, is_error, content)| ResultBlock {
            block_type,
            is_error,
            content,
        },
    )
}

fn render_result_block(block: &ResultBlock) -> Value {
    let mut rendered = json!({
        "type": block.block_type,
        "tool_use_id": "toolu_01",
        "content": render_tool_result_content(&block.content),
        "text": "a text block",
    });
    if !block.is_error.is_null() {
        rendered["is_error"] = block.is_error.clone();
    }
    rendered
}

fn is_failed_block(block: &ResultBlock) -> bool {
    block.block_type == "tool_result" && block.is_error == json!(true)
}

fn failure_of(content: &ToolResultContent) -> AgentEvent {
    let given_text = read_tool_result_text(content);
    AgentEvent::ToolFailed(expect_given_text(
        &given_text,
        UNKNOWN_TOOL_FAILURE,
    ))
}

fn failed_content_line(content: &Value) -> String {
    let block = json!({
        "type": "tool_result",
        "tool_use_id": "toolu_01",
        "content": content,
        "is_error": true,
    });
    user_line(&json!([block]))
}

fn any_unreadable_content() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        any::<i64>().prop_map(|number| json!(number)),
        any::<String>().prop_map(|text| json!({"text": text})),
        Just(json!([{"type": "image", "source": {"data": "aGk="}}])),
    ]
}

proptest! {
    #[test]
    fn test_describe_tool_failures_property_one_failure_per_failed_block(
        blocks in vec(any_result_block(), 0..LARGEST_BLOCK_COUNT),
    ) {
        let rendered: Vec<Value> =
            blocks.iter().map(render_result_block).collect();

        let agent_events = parse_claude(&user_line(&json!(rendered)));

        let mut expected = Vec::new();
        for block in blocks.iter().filter(|block| is_failed_block(block)) {
            expected.push(failure_of(&block.content));
        }
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_describe_tool_failures_property_typed_messages_give_nothing(
        text in any::<String>(),
    ) {
        let typed_message = user_line(&json!(text));

        prop_assert_eq!(parse_claude(&typed_message), Vec::new());
    }

    #[test]
    fn test_describe_tool_failures_property_succeeded_results_give_nothing(
        contents in vec(any_tool_result_content(), 0..LARGEST_BLOCK_COUNT),
    ) {
        let mut agent_events = Vec::new();
        for content in &contents {
            let line = tool_result_line(content, ToolOutcome::Succeeded);
            agent_events.extend(parse_claude(&line));
        }

        prop_assert_eq!(agent_events, Vec::new());
    }

    #[test]
    fn test_is_failed_tool_result_property_needs_a_true_error_flag(
        block in any_result_block(),
    ) {
        let line = user_line(&json!([render_result_block(&block)]));

        let has_failure = !parse_claude(&line).is_empty();

        prop_assert_eq!(has_failure, is_failed_block(&block));
    }

    #[test]
    fn test_is_failed_tool_result_property_other_block_types_never_fail(
        block_type in "[a-z_]{1,12}",
        content in any_tool_result_content(),
    ) {
        prop_assume!(block_type != "tool_result");
        let block = json!({
            "type": block_type,
            "content": render_tool_result_content(&content),
            "is_error": true,
        });

        prop_assert_eq!(parse_claude(&user_line(&json!([block]))), Vec::new());
    }

    #[test]
    fn test_is_failed_tool_result_property_failures_need_no_tool_id(
        content in any_tool_result_content(),
    ) {
        let block = json!({
            "type": "tool_result",
            "content": render_tool_result_content(&content),
            "is_error": true,
        });

        let agent_events = parse_claude(&user_line(&json!([block])));

        prop_assert_eq!(agent_events, vec![failure_of(&content)]);
    }

    #[test]
    fn test_read_error_text_property_plain_text_is_trimmed(
        text in any::<String>(),
        padding in "[ \n\t\r]{0,4}",
    ) {
        let padded = format!("{padding}{text}{padding}");

        let agent_events = parse_claude(&failed_content_line(&json!(padded)));

        let expected = expect_given_text(&text, UNKNOWN_TOOL_FAILURE);
        prop_assert_eq!(agent_events, vec![AgentEvent::ToolFailed(expected)]);
    }

    #[test]
    fn test_read_error_text_property_unreadable_content_is_unknown(
        content in any_unreadable_content(),
    ) {
        let agent_events = parse_claude(&failed_content_line(&content));

        let expected = AgentEvent::ToolFailed(UNKNOWN_TOOL_FAILURE.to_owned());
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_read_error_text_property_missing_content_is_unknown(
        tool_use_id in "toolu_[a-zA-Z0-9]{1,12}",
    ) {
        let block = json!({
            "type": "tool_result",
            "tool_use_id": tool_use_id,
            "is_error": true,
        });

        let agent_events = parse_claude(&user_line(&json!([block])));

        let expected = AgentEvent::ToolFailed(UNKNOWN_TOOL_FAILURE.to_owned());
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_join_text_blocks_property_keeps_order_with_line_breaks(
        texts in vec("[a-zA-Z0-9é中 .:]{1,12}", 1..LARGEST_BLOCK_COUNT),
    ) {
        let content = ToolResultContent::TextBlocks(texts.clone());
        let line = tool_result_line(&content, ToolOutcome::Failed);

        let agent_events = parse_claude(&line);

        let joined = texts.join("\n");
        let expected = expect_given_text(&joined, UNKNOWN_TOOL_FAILURE);
        prop_assert_eq!(agent_events, vec![AgentEvent::ToolFailed(expected)]);
    }

    #[test]
    fn test_join_text_blocks_property_skips_blocks_without_text(
        texts in vec("[a-z]{1,8}", 1..LARGEST_BLOCK_COUNT),
        number in any::<i64>(),
    ) {
        let mut blocks = Vec::new();
        for text in &texts {
            blocks.push(json!({"type": "image", "source": {}}));
            blocks.push(json!({"type": "text", "text": text}));
            blocks.push(json!({"type": "text", "text": number}));
        }

        let agent_events = parse_claude(&failed_content_line(&json!(blocks)));

        let expected = AgentEvent::ToolFailed(texts.join("\n"));
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_join_text_blocks_property_one_block_reads_like_plain_text(
        text in any::<String>(),
    ) {
        let block_content = ToolResultContent::TextBlocks(vec![text.clone()]);
        let plain_content = ToolResultContent::Plain(text);

        let from_blocks = parse_claude(&tool_result_line(
            &block_content,
            ToolOutcome::Failed,
        ));
        let from_plain = parse_claude(&tool_result_line(
            &plain_content,
            ToolOutcome::Failed,
        ));

        prop_assert_eq!(from_blocks, from_plain);
    }
}

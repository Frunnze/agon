use proptest::prelude::*;
use serde_json::{Value, json};

#[derive(Clone, Copy, Debug)]
pub enum ToolOutcome {
    Failed,
    Succeeded,
}

#[derive(Clone, Debug)]
pub enum ToolResultContent {
    Plain(String),
    TextBlocks(Vec<String>),
}

pub fn any_tool_result_content() -> impl Strategy<Value = ToolResultContent> {
    prop_oneof![
        any::<String>().prop_map(ToolResultContent::Plain),
        proptest::collection::vec(any::<String>(), 0..3)
            .prop_map(ToolResultContent::TextBlocks),
    ]
}

pub fn render_tool_result_content(content: &ToolResultContent) -> Value {
    match content {
        ToolResultContent::Plain(text) => json!(text),
        ToolResultContent::TextBlocks(texts) => {
            let mut blocks = Vec::new();
            for text in texts {
                blocks.push(json!({"type": "text", "text": text}));
            }
            Value::Array(blocks)
        }
    }
}

pub fn read_tool_result_text(content: &ToolResultContent) -> String {
    match content {
        ToolResultContent::Plain(text) => text.trim().to_string(),
        ToolResultContent::TextBlocks(texts) => texts.join("\n").trim().into(),
    }
}

pub fn tool_result_line(
    content: &ToolResultContent,
    outcome: ToolOutcome,
) -> String {
    let is_error = matches!(outcome, ToolOutcome::Failed);
    let block = json!({
        "type": "tool_result",
        "tool_use_id": "toolu_01",
        "content": render_tool_result_content(content),
        "is_error": is_error,
    });
    user_line(&Value::Array(vec![block]))
}

pub fn user_line(content: &Value) -> String {
    json!({
        "type": "user",
        "message": {"role": "user", "content": content},
        "session_id": "5f0c3e2a",
    })
    .to_string()
}

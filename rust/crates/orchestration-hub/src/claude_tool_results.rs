use serde_json::Value;

use crate::agent_event::AgentEvent;
use crate::failure_texts::{UNKNOWN_TOOL_FAILURE, choose_given_text};

const CONTENT_FIELD: &str = "content";
const TYPE_FIELD: &str = "type";
const IS_ERROR_FIELD: &str = "is_error";
const TEXT_FIELD: &str = "text";
const TOOL_RESULT_TYPE: &str = "tool_result";
const TEXT_BLOCK_SEPARATOR: &str = "\n";

pub(crate) fn describe_tool_failures(message: &Value) -> Vec<AgentEvent> {
    let content = message.get(CONTENT_FIELD).and_then(Value::as_array);
    let Some(blocks) = content else {
        return Vec::new();
    };

    let mut failures = Vec::new();
    for block in blocks {
        if is_failed_tool_result(block) {
            let error_text = read_error_text(block.get(CONTENT_FIELD));
            failures.push(AgentEvent::ToolFailed(error_text));
        }
    }
    failures
}

fn is_failed_tool_result(block: &Value) -> bool {
    let block_type = block.get(TYPE_FIELD).and_then(Value::as_str);
    let is_error = block.get(IS_ERROR_FIELD).and_then(Value::as_bool);
    block_type == Some(TOOL_RESULT_TYPE) && is_error == Some(true)
}

fn read_error_text(content: Option<&Value>) -> String {
    let given_text = match content {
        Some(Value::String(text)) => text.clone(),
        Some(Value::Array(blocks)) => join_text_blocks(blocks),
        _ => String::new(),
    };

    choose_given_text(&[&given_text], UNKNOWN_TOOL_FAILURE)
}

fn join_text_blocks(blocks: &[Value]) -> String {
    let mut texts = Vec::new();
    for block in blocks {
        if let Some(text) = block.get(TEXT_FIELD).and_then(Value::as_str) {
            texts.push(text);
        }
    }
    texts.join(TEXT_BLOCK_SEPARATOR)
}

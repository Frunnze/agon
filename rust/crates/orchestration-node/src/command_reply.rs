use serde::Serialize;
use serde_json::{Value, json};

use crate::node_error::NodeError;

#[must_use]
pub fn render_success_reply(success: &Value) -> String {
    json!({ "ok": success }).to_string()
}

#[must_use]
pub fn render_error_reply(message: &str) -> String {
    json!({ "error": message }).to_string()
}

#[must_use]
pub fn render_reply(outcome: &Result<Value, NodeError>) -> String {
    match outcome {
        Ok(success) => render_success_reply(success),
        Err(error) => render_error_reply(&error.to_string()),
    }
}

pub fn encode_reply<View: Serialize>(view: &View) -> Result<Value, NodeError> {
    Ok(serde_json::to_value(view)?)
}

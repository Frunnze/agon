use serde::Serialize;
use serde_json::{Value, json};

use crate::node_error::NodeError;

const NO_ACCOUNT_KIND: &str = "no_account";

#[must_use]
pub fn render_success_reply(success: &Value) -> String {
    json!({ "ok": success }).to_string()
}

#[must_use]
pub fn render_error_reply(message: &str) -> String {
    json!({ "error": message }).to_string()
}

#[must_use]
pub fn render_node_error_reply(error: &NodeError) -> String {
    let message = error.to_string();
    match name_error_kind(error) {
        Some(kind) => {
            json!({ "error": message, "error_kind": kind }).to_string()
        }
        None => render_error_reply(&message),
    }
}

#[must_use]
pub fn render_reply(outcome: &Result<Value, NodeError>) -> String {
    match outcome {
        Ok(success) => render_success_reply(success),
        Err(error) => render_node_error_reply(error),
    }
}

fn name_error_kind(error: &NodeError) -> Option<&'static str> {
    if matches!(error, NodeError::NoAccount) {
        return Some(NO_ACCOUNT_KIND);
    }
    None
}

pub fn encode_reply<View: Serialize>(view: &View) -> Result<Value, NodeError> {
    Ok(serde_json::to_value(view)?)
}

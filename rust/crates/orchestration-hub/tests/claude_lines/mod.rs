use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::agent_reading::parse_agent_line;

pub fn any_detail() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9_./=-][a-zA-Z0-9 _./=-]{0,58}[a-zA-Z0-9_./=-]"
}

pub fn assistant_line(content: &Value) -> String {
    json!({
        "type": "assistant",
        "message": {"role": "assistant", "content": content},
        "session_id": "5f0c3e2a",
    })
    .to_string()
}

pub fn parse_claude(line: &str) -> Vec<AgentEvent> {
    parse_agent_line(AgentKind::ClaudeCode, line)
}

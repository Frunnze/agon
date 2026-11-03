use serde_json::Value;

use crate::agent_event::AgentEvent;

pub(crate) fn reads_as_json(text: &str) -> bool {
    let parsed = serde_json::from_str::<Value>(text);
    parsed.is_ok_and(|value| value.is_object() || value.is_array())
}

pub(crate) fn describe_unread_line(line: &str) -> Vec<AgentEvent> {
    if reads_as_json(line) {
        return Vec::new();
    }
    vec![AgentEvent::Said(line.to_string())]
}

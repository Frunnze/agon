use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;

use crate::stream_support::read_container_events;

pub fn any_speech_parts() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::vec("[a-zA-Z0-9,.']{1,8} ?", 1..5)
}

pub fn any_printed_line() -> impl Strategy<Value = String> {
    "[a-zA-Z][a-zA-Z0-9 .:]{0,30}[a-zA-Z0-9.]"
}

pub fn read_gemini(lines: &[String]) -> Vec<AgentEvent> {
    read_container_events(AgentKind::GeminiCli, lines)
}

pub fn said_speech(parts: &[String]) -> Vec<AgentEvent> {
    let speech = parts.concat();
    let spoken = speech.trim();
    if spoken.is_empty() {
        return Vec::new();
    }
    vec![AgentEvent::Said(spoken.to_owned())]
}

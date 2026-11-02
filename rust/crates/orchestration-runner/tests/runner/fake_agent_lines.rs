use proptest::prelude::*;
use serde_json::{Value, json};

const SENTENCE_PATTERN: &str =
    concat!("[a-zA-Z0-9,.']{1,12}", "( [a-zA-Z0-9,.']{1,12}){0,4}");
const COMMAND_PATTERN: &str = "[a-z./-]{1,10}( [a-z./-]{1,10}){0,2}";
const SESSION_PATTERN: &str = "[a-z0-9]{4,12}";
const PLAIN_PATTERN: &str = "[a-zA-Z0-9 ,.:_-]{0,40}";

#[derive(Clone, Debug)]
pub enum FakeAgentLine {
    Said(String),
    UsedBash(String),
    ToolError(String),
    Session(String),
    Finished,
    Plain(String),
}

pub fn any_fake_agent_line() -> impl Strategy<Value = FakeAgentLine> {
    prop_oneof![
        SENTENCE_PATTERN.prop_map(FakeAgentLine::Said),
        COMMAND_PATTERN.prop_map(FakeAgentLine::UsedBash),
        SENTENCE_PATTERN.prop_map(FakeAgentLine::ToolError),
        SESSION_PATTERN.prop_map(FakeAgentLine::Session),
        Just(FakeAgentLine::Finished),
        PLAIN_PATTERN.prop_map(FakeAgentLine::Plain),
    ]
}

pub fn render_line(line: &FakeAgentLine) -> String {
    let rendered = match line {
        FakeAgentLine::Said(text) => json!({
            "type": "assistant",
            "message": {"content": [{"type": "text", "text": text}]},
        }),
        FakeAgentLine::UsedBash(command) => json!({
            "type": "assistant",
            "message": {"content": [{
                "type": "tool_use",
                "name": "Bash",
                "input": {"command": command},
            }]},
        }),
        FakeAgentLine::ToolError(error) => json!({
            "type": "user",
            "message": {"content": [{
                "type": "tool_result",
                "content": error,
                "is_error": true,
            }]},
        }),
        FakeAgentLine::Session(session) => json!({
            "type": "system",
            "subtype": "init",
            "session_id": session,
        }),
        FakeAgentLine::Finished => json!({
            "type": "result",
            "subtype": "success",
            "is_error": false,
            "result": "done",
        }),
        FakeAgentLine::Plain(text) => return text.clone(),
    };
    rendered.to_string()
}

pub fn reads_as_json(text: &str) -> bool {
    let words: Vec<&str> = text.split_whitespace().collect();
    let one_line = words.join(" ");
    serde_json::from_str::<Value>(&one_line)
        .is_ok_and(|value| value.is_object() || value.is_array())
}

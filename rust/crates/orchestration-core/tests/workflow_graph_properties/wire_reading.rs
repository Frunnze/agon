use serde::Deserialize;
use serde_json::Value;

const SHARED_WIRE_CASES: &str =
    include_str!("../fixtures/workflow_wire_cases.json");

#[derive(Debug, Deserialize)]
pub struct SharedWireCases {
    pub agent_kinds: Vec<String>,
    pub step_kinds: Vec<String>,
    pub signature_states: Vec<String>,
    pub workflow: Value,
}

pub fn read_wire_cases() -> Result<SharedWireCases, serde_json::Error> {
    serde_json::from_str(SHARED_WIRE_CASES)
}

pub fn list_keys(json_value: &Value) -> Vec<String> {
    json_value
        .as_object()
        .map(|fields| fields.keys().cloned().collect())
        .unwrap_or_default()
}

pub fn without_fields(json_value: &Value, fields: &[&str]) -> Value {
    let mut trimmed = json_value.clone();
    if let Some(object) = trimmed.as_object_mut() {
        for field in fields {
            object.remove(*field);
        }
    }
    trimmed
}

pub fn read_wire_part(pointer: &str) -> Result<Value, serde_json::Error> {
    let cases = read_wire_cases()?;
    Ok(cases
        .workflow
        .pointer(pointer)
        .cloned()
        .unwrap_or(Value::Null))
}

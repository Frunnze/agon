use serde_json::{Map, Value};

use crate::terminal_text::strip_terminal_control_sequences;

pub(crate) fn strip_terminal_codes_in_json(line: &str) -> String {
    let Ok(document) = serde_json::from_str::<Value>(line) else {
        return line.to_string();
    };
    if !document.is_object() && !document.is_array() {
        return line.to_string();
    }
    strip_terminal_codes_in_texts(document).to_string()
}

fn strip_terminal_codes_in_texts(document: Value) -> Value {
    match document {
        Value::String(text) => {
            Value::String(strip_terminal_control_sequences(&text))
        }
        Value::Array(elements) => {
            let mut visible_elements = Vec::new();
            for element in elements {
                visible_elements.push(strip_terminal_codes_in_texts(element));
            }
            Value::Array(visible_elements)
        }
        Value::Object(fields) => {
            let mut visible_fields = Map::new();
            for (name, field) in fields {
                let visible_field = strip_terminal_codes_in_texts(field);
                visible_fields.insert(name, visible_field);
            }
            Value::Object(visible_fields)
        }
        Value::Null | Value::Bool(_) | Value::Number(_) => document,
    }
}

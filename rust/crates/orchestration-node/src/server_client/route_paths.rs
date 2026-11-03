use crate::node_error::NodeError;

const PLACEHOLDER_START: char = '{';
const PLACEHOLDER_END: char = '}';
const ALLOWED_PUNCTUATION: char = '-';
const PERCENT_SIGN: char = '%';

pub fn fill_route(
    template: &str,
    values: &[(&str, &str)],
) -> Result<String, NodeError> {
    let mut filled_route = template.to_owned();
    for (placeholder, value) in values {
        if !is_path_segment(value) {
            return Err(NodeError::InvalidRouteValue((*value).to_owned()));
        }
        let marker =
            format!("{PLACEHOLDER_START}{placeholder}{PLACEHOLDER_END}");
        filled_route = filled_route.replace(&marker, value);
    }

    if filled_route.contains(PLACEHOLDER_START) {
        return Err(NodeError::MissingRouteValue(template.to_owned()));
    }
    Ok(filled_route)
}

fn is_path_segment(value: &str) -> bool {
    let has_only_safe_characters = value.chars().all(|character| {
        character.is_ascii_alphanumeric() || character == ALLOWED_PUNCTUATION
    });
    !value.is_empty() && has_only_safe_characters
}

#[must_use]
pub fn encode_path_segment(text: &str) -> String {
    let mut encoded = String::new();
    for byte in text.bytes() {
        let character = char::from(byte);
        let is_kept = character.is_ascii_alphanumeric()
            || character == ALLOWED_PUNCTUATION;
        if is_kept {
            encoded.push(character);
        } else {
            let escape = format!("{PERCENT_SIGN}{byte:02X}");
            encoded.push_str(&escape);
        }
    }
    encoded
}

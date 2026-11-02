use std::ops::RangeInclusive;

const RESERVED_PLAIN_WORDS: [&str; 9] =
    ["true", "false", "null", "yes", "no", "on", "off", "y", "n"];
const INVISIBLE_CHARACTER_RANGES: [RangeInclusive<char>; 4] = [
    '\u{200B}'..='\u{200F}',
    '\u{2028}'..='\u{202E}',
    '\u{2060}'..='\u{2069}',
    '\u{FEFF}'..='\u{FEFF}',
];

pub(crate) fn render_yaml_scalar(text: &str) -> String {
    if is_plain_scalar(text) {
        return text.to_owned();
    }
    quote_yaml_text(text)
}

pub(crate) fn render_yaml_list(items: &[String]) -> String {
    let rendered_items: Vec<String> =
        items.iter().map(|item| render_yaml_scalar(item)).collect();
    format!("[{}]", rendered_items.join(", "))
}

fn is_plain_scalar(text: &str) -> bool {
    let starts_with_letter = text
        .chars()
        .next()
        .is_some_and(|character| character.is_ascii_lowercase());
    let has_only_plain_characters = text.chars().all(|character| {
        character.is_ascii_lowercase()
            || character.is_ascii_digit()
            || character == '-'
    });
    let is_reserved = RESERVED_PLAIN_WORDS.contains(&text);
    starts_with_letter && has_only_plain_characters && !is_reserved
}

fn quote_yaml_text(text: &str) -> String {
    let mut quoted = String::from("\"");
    for character in text.chars() {
        match character {
            '"' => quoted.push_str("\\\""),
            '\\' => quoted.push_str("\\\\"),
            '\n' => quoted.push_str("\\n"),
            '\t' => quoted.push_str("\\t"),
            _ if is_hidden_character(character) => {
                let escape_sequence =
                    format!("\\u{:04X}", u32::from(character));
                quoted.push_str(&escape_sequence);
            }
            _ => quoted.push(character),
        }
    }
    quoted.push('"');
    quoted
}

fn is_hidden_character(character: char) -> bool {
    let is_invisible = INVISIBLE_CHARACTER_RANGES
        .iter()
        .any(|range| range.contains(&character));
    character.is_control() || is_invisible
}

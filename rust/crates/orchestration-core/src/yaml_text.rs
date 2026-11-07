use std::ops::RangeInclusive;

const RESERVED_PLAIN_WORDS: [&str; 9] =
    ["true", "false", "null", "yes", "no", "on", "off", "y", "n"];
const INVISIBLE_CHARACTER_RANGES: [RangeInclusive<char>; 18] = [
    '\u{AD}'..='\u{AD}',
    '\u{34F}'..='\u{34F}',
    '\u{61C}'..='\u{61C}',
    '\u{115F}'..='\u{1160}',
    '\u{17B4}'..='\u{17B5}',
    '\u{180B}'..='\u{180F}',
    '\u{200B}'..='\u{200F}',
    '\u{2028}'..='\u{202E}',
    '\u{2060}'..='\u{206F}',
    '\u{3164}'..='\u{3164}',
    '\u{FE00}'..='\u{FE0F}',
    '\u{FEFF}'..='\u{FEFF}',
    '\u{FFA0}'..='\u{FFA0}',
    '\u{FFF0}'..='\u{FFF8}',
    '\u{FFFE}'..='\u{FFFF}',
    '\u{1BCA0}'..='\u{1BCA3}',
    '\u{1D173}'..='\u{1D17A}',
    '\u{E0000}'..='\u{E0FFF}',
];
const LARGEST_SHORT_ESCAPE: char = '\u{FFFF}';

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
                quoted.push_str(&escape_hidden_character(character));
            }
            _ => quoted.push(character),
        }
    }
    quoted.push('"');
    quoted
}

fn escape_hidden_character(character: char) -> String {
    let code_point = u32::from(character);
    if character <= LARGEST_SHORT_ESCAPE {
        return format!("\\u{code_point:04X}");
    }
    format!("\\U{code_point:08X}")
}

fn is_hidden_character(character: char) -> bool {
    let is_invisible = INVISIBLE_CHARACTER_RANGES
        .iter()
        .any(|range| range.contains(&character));
    character.is_control() || is_invisible
}

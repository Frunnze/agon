use std::ops::RangeInclusive;
use std::str::Chars;

const QUOTE: char = '"';
const BACKSLASH: char = '\\';
const SHORT_ESCAPE_DIGITS: usize = 4;
const LONG_ESCAPE_DIGITS: usize = 8;
const BYTE_ESCAPE_DIGITS: usize = 2;
const HEXADECIMAL_RADIX: u32 = 16;
const LIST_OPENING: char = '[';
const LIST_CLOSING: char = ']';
const ITEM_SEPARATOR: &str = ", ";
const YAML_PRINTABLE_RANGES: [RangeInclusive<char>; 7] = [
    '\u{9}'..='\u{A}',
    '\u{D}'..='\u{D}',
    '\u{20}'..='\u{7E}',
    '\u{85}'..='\u{85}',
    '\u{A0}'..='\u{D7FF}',
    '\u{E000}'..='\u{FFFD}',
    '\u{10000}'..='\u{10FFFF}',
];
const DEFAULT_IGNORABLE_RANGES: [RangeInclusive<char>; 17] = [
    '\u{AD}'..='\u{AD}',
    '\u{34F}'..='\u{34F}',
    '\u{61C}'..='\u{61C}',
    '\u{115F}'..='\u{1160}',
    '\u{17B4}'..='\u{17B5}',
    '\u{180B}'..='\u{180F}',
    '\u{200B}'..='\u{200F}',
    '\u{202A}'..='\u{202E}',
    '\u{2060}'..='\u{206F}',
    '\u{3164}'..='\u{3164}',
    '\u{FE00}'..='\u{FE0F}',
    '\u{FEFF}'..='\u{FEFF}',
    '\u{FFA0}'..='\u{FFA0}',
    '\u{FFF0}'..='\u{FFF8}',
    '\u{1BCA0}'..='\u{1BCA3}',
    '\u{1D173}'..='\u{1D17A}',
    '\u{E0000}'..='\u{E0FFF}',
];
const LINE_BREAKS: [char; 5] = ['\n', '\r', '\u{85}', '\u{2028}', '\u{2029}'];

pub fn find_field<'document>(
    document: &'document str,
    field_prefix: &str,
) -> Option<&'document str> {
    let mut lines = document.lines();
    lines.find_map(|line| line.strip_prefix(field_prefix))
}

pub fn decode_yaml_scalar(rendered: &str) -> Option<String> {
    let Some(quoted_body) = rendered.strip_prefix(QUOTE) else {
        return Some(rendered.to_owned());
    };
    let mut characters = quoted_body.chars();
    let decoded = decode_quoted_body(&mut characters)?;
    let rest: String = characters.collect();
    rest.is_empty().then_some(decoded)
}

pub fn decode_yaml_list(rendered: &str) -> Option<Vec<String>> {
    let inner = rendered
        .strip_prefix(LIST_OPENING)?
        .strip_suffix(LIST_CLOSING)?;
    let mut items = Vec::new();
    let mut rest = inner;
    while !rest.is_empty() {
        let item_length = measure_item(rest)?;
        items.push(decode_yaml_scalar(&rest[..item_length])?);
        rest = &rest[item_length..];
        if !rest.is_empty() {
            rest = rest.strip_prefix(ITEM_SEPARATOR)?;
        }
    }
    Some(items)
}

pub fn is_yaml_printable(character: char) -> bool {
    YAML_PRINTABLE_RANGES
        .iter()
        .any(|range| range.contains(&character))
}

pub fn is_line_break(character: char) -> bool {
    LINE_BREAKS.contains(&character)
}

pub fn is_default_ignorable(character: char) -> bool {
    DEFAULT_IGNORABLE_RANGES
        .iter()
        .any(|range| range.contains(&character))
}

fn measure_item(rest: &str) -> Option<usize> {
    if !rest.starts_with(QUOTE) {
        let plain_length = rest.find(ITEM_SEPARATOR).unwrap_or(rest.len());
        return Some(plain_length);
    }
    let mut characters = rest[1..].chars();
    decode_quoted_body(&mut characters)?;
    let remaining_length = characters.as_str().len();
    Some(rest.len() - remaining_length)
}

fn decode_quoted_body(characters: &mut Chars<'_>) -> Option<String> {
    let mut decoded = String::new();
    loop {
        let character = characters.next()?;
        if character == QUOTE {
            return Some(decoded);
        }
        if character != BACKSLASH {
            decoded.push(character);
            continue;
        }
        decoded.push(decode_escape(characters)?);
    }
}

fn decode_escape(characters: &mut Chars<'_>) -> Option<char> {
    let escape = characters.next()?;
    match escape {
        QUOTE | BACKSLASH | '/' => Some(escape),
        'n' => Some('\n'),
        't' => Some('\t'),
        'r' => Some('\r'),
        '0' => Some('\0'),
        'x' => read_code_point(characters, BYTE_ESCAPE_DIGITS),
        'u' => read_code_point(characters, SHORT_ESCAPE_DIGITS),
        'U' => read_code_point(characters, LONG_ESCAPE_DIGITS),
        _ => None,
    }
}

fn read_code_point(
    characters: &mut Chars<'_>,
    digit_count: usize,
) -> Option<char> {
    let mut digits = String::new();
    for _ in 0..digit_count {
        digits.push(characters.next()?);
    }
    if !digits.chars().all(|digit| digit.is_ascii_hexdigit()) {
        return None;
    }
    let code_point = u32::from_str_radix(&digits, HEXADECIMAL_RADIX).ok()?;
    char::from_u32(code_point)
}

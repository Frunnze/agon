use proptest::prelude::*;

pub const LONGEST_FOLDER_NAME_BYTES: usize = 255;
pub const ESCAPE_MARKER: char = '_';
pub const SHORTENED_NAME_SEPARATOR: char = '.';

fn is_kept_byte(byte: u8) -> bool {
    byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'-'
}

pub fn escape_like_today(address: &str) -> String {
    let mut escaped_pieces = Vec::new();
    for byte in address.bytes() {
        if is_kept_byte(byte) {
            escaped_pieces.push(char::from(byte).to_string());
        } else {
            escaped_pieces.push(format!("{ESCAPE_MARKER}{byte:02x}"));
        }
    }
    escaped_pieces.concat()
}

pub fn any_long_address() -> impl Strategy<Value = String> {
    prop_oneof![
        concat!(
            "[a-z]{1,12}\\.[a-z]{2,4}/[A-Za-z0-9_.-]{1,39}/",
            "[A-Z][A-Za-z0-9_.-]{80,100}",
        ),
        "[A-Z._/]{86,400}",
        "local/[a-zA-Z0-9 _./-]{100,300}",
        "[中😀é]{22,80}",
    ]
}

pub fn any_address() -> impl Strategy<Value = String> {
    prop_oneof![any::<String>(), any_long_address(), "[a-z0-9-]{200,300}"]
}

pub fn split_shortened_name(name: &str) -> Option<(&str, &str)> {
    name.split_once(SHORTENED_NAME_SEPARATOR)
}

use orchestration_hub::agent_log::describe_agent_log_lines;
use orchestration_hub::terminal_screen::{TerminalScreen, TerminalSize};
use proptest::prelude::*;

pub const WIDE_SIZE: TerminalSize = TerminalSize {
    columns: 200,
    rows: 60,
};
pub const ESCAPE: &str = "\u{1b}";
pub const STRING_TERMINATOR: &str = "\u{1b}\\";
pub const BELL: &str = "\u{7}";
pub const LOG_LINE_START: &str = "note:";

pub fn show(text: &str) -> Vec<String> {
    let mut screen = TerminalScreen::new(WIDE_SIZE);
    screen.feed(text);
    screen.lines()
}

pub fn show_in_pieces(pieces: &[String]) -> Vec<String> {
    let mut screen = TerminalScreen::new(WIDE_SIZE);
    for piece in pieces {
        screen.feed(piece);
    }
    screen.lines()
}

pub fn show_in_log(text: &str) -> String {
    let line = format!("{LOG_LINE_START}{text}");
    let log_lines = describe_agent_log_lines(&line, &[]);
    let mut shown = String::new();
    for log_line in log_lines {
        shown.push_str(&log_line.text);
    }
    shown
}

pub fn any_plain_text() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9 é中😀.,;:!?'\"(){}<>/|@#$%^&*~`+=_\\[\\]\\\\-]{0,30}"
}

pub fn any_string_payload() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9 ;:/.?=&é中\\[\\]-]{0,24}"
}

pub fn any_parameters() -> impl Strategy<Value = String> {
    "[0-9;]{0,10}"
}

pub fn any_charset_designation() -> impl Strategy<Value = String> {
    ("[ -/]{1,2}", "[0-9A-Za-z<=>@`]").prop_map(
        |(intermediates, final_character)| {
            format!("{ESCAPE}{intermediates}{final_character}")
        },
    )
}

pub fn any_two_character_escape() -> impl Strategy<Value = String> {
    "[0-9A-OQ-WYZa-z=>@`{|}~]"
        .prop_map(|final_character| format!("{ESCAPE}{final_character}"))
}

pub fn any_control_string() -> impl Strategy<Value = String> {
    let opener = prop_oneof![Just('P'), Just('X'), Just('^'), Just('_')];
    (opener, any_string_payload()).prop_map(|(opener, payload)| {
        format!("{ESCAPE}{opener}{payload}{STRING_TERMINATOR}")
    })
}

pub fn any_operating_system_command() -> impl Strategy<Value = String> {
    let terminator = prop_oneof![Just(BELL), Just(STRING_TERMINATOR)];
    (any_string_payload(), terminator).prop_map(|(payload, terminator)| {
        format!("{ESCAPE}]{payload}{terminator}")
    })
}

pub fn any_still_sequence() -> impl Strategy<Value = String> {
    let colour = any_parameters()
        .prop_map(|parameters| format!("{ESCAPE}[{parameters}m"));
    let private_mode = ("[?<=>]", "[0-9;]{0,6}", "[hlcnpqtu]").prop_map(
        |(marker, parameters, final_character)| {
            format!("{ESCAPE}[{marker}{parameters}{final_character}")
        },
    );
    prop_oneof![
        colour,
        private_mode,
        any_operating_system_command(),
        any_control_string(),
        any_charset_designation(),
        any_two_character_escape(),
    ]
}

pub fn shown_alone(text: &str) -> Vec<String> {
    let trimmed = text.trim_end();
    if trimmed.is_empty() {
        return Vec::new();
    }
    vec![trimmed.to_owned()]
}

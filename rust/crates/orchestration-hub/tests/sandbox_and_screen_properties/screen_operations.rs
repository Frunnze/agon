use orchestration_hub::terminal_screen::{TerminalScreen, TerminalSize};
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::select;

use crate::reference_screen::ReferenceScreen;

pub const NARROW_CHARACTERS: [char; 8] =
    ['a', 'Z', '7', ' ', 'é', 'ß', '→', '─'];
pub const WIDE_CHARACTERS: [char; 4] = ['中', '한', '😀', 'Ｗ'];
pub const MARK_CHARACTERS: [char; 2] = ['\u{301}', '\u{308}'];
pub const IGNORED_SEQUENCES: [&str; 9] = [
    "\u{1b}[1;31m",
    "\u{1b}[0m",
    "\u{1b}]0;window title\u{7}",
    "\u{1b}]8;;https://example.com\u{1b}\\",
    "\u{1b}(B",
    "\u{1b})0",
    "\u{1b}[?25l",
    "\u{1b}[?2004h",
    "\u{1b}[2 q",
];
const LARGEST_COUNT: usize = 6;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScreenOperation {
    Print(char),
    LineFeed,
    CarriageReturn,
    Backspace,
    Tab,
    Up(usize),
    Down(usize),
    Forward(usize),
    Back(usize),
    NextLine(usize),
    PreviousLine(usize),
    Column(usize),
    Position(usize, usize),
    EraseLine(usize),
    EraseDisplay(usize),
    Ignored(&'static str),
}

pub fn any_narrow_print() -> BoxedStrategy<ScreenOperation> {
    select(NARROW_CHARACTERS.to_vec())
        .prop_map(ScreenOperation::Print)
        .boxed()
}

pub fn any_unicode_print() -> BoxedStrategy<ScreenOperation> {
    let mut characters = NARROW_CHARACTERS.to_vec();
    characters.extend(WIDE_CHARACTERS);
    characters.extend(MARK_CHARACTERS);
    select(characters).prop_map(ScreenOperation::Print).boxed()
}

fn position_at((row, column): (usize, usize)) -> ScreenOperation {
    ScreenOperation::Position(row, column)
}

pub fn any_cursor_move() -> BoxedStrategy<ScreenOperation> {
    let count = 0..LARGEST_COUNT;
    prop_oneof![
        Just(ScreenOperation::LineFeed),
        Just(ScreenOperation::CarriageReturn),
        Just(ScreenOperation::Backspace),
        Just(ScreenOperation::Tab),
        count.clone().prop_map(ScreenOperation::Up),
        count.clone().prop_map(ScreenOperation::Down),
        count.clone().prop_map(ScreenOperation::Forward),
        count.clone().prop_map(ScreenOperation::Back),
        count.clone().prop_map(ScreenOperation::NextLine),
        count.clone().prop_map(ScreenOperation::PreviousLine),
        (0..14_usize).prop_map(ScreenOperation::Column),
        (0..8_usize, 0..14_usize).prop_map(position_at),
    ]
    .boxed()
}

pub fn any_erase() -> BoxedStrategy<ScreenOperation> {
    prop_oneof![
        (0..3_usize).prop_map(ScreenOperation::EraseLine),
        (0..4_usize).prop_map(ScreenOperation::EraseDisplay),
    ]
    .boxed()
}

pub fn any_ignored() -> BoxedStrategy<ScreenOperation> {
    select(IGNORED_SEQUENCES.to_vec())
        .prop_map(ScreenOperation::Ignored)
        .boxed()
}

pub fn any_operations(
    print: BoxedStrategy<ScreenOperation>,
) -> impl Strategy<Value = Vec<ScreenOperation>> {
    let operation = prop_oneof![
        4 => print,
        2 => any_cursor_move(),
        1 => any_erase(),
        1 => any_ignored(),
    ];
    vec(operation, 0..80)
}

pub fn any_size() -> impl Strategy<Value = TerminalSize> {
    (2_u16..12, 1_u16..6)
        .prop_map(|(columns, rows)| TerminalSize { columns, rows })
}

pub fn render(operations: &[ScreenOperation]) -> String {
    let mut text = String::new();
    for operation in operations {
        text.push_str(&render_operation(*operation));
    }
    text
}

fn render_operation(operation: ScreenOperation) -> String {
    match operation {
        ScreenOperation::Print(character) => character.to_string(),
        ScreenOperation::LineFeed => "\n".to_owned(),
        ScreenOperation::CarriageReturn => "\r".to_owned(),
        ScreenOperation::Backspace => "\u{8}".to_owned(),
        ScreenOperation::Tab => "\t".to_owned(),
        ScreenOperation::Up(count) => format!("\u{1b}[{count}A"),
        ScreenOperation::Down(count) => format!("\u{1b}[{count}B"),
        ScreenOperation::Forward(count) => format!("\u{1b}[{count}C"),
        ScreenOperation::Back(count) => format!("\u{1b}[{count}D"),
        ScreenOperation::NextLine(count) => format!("\u{1b}[{count}E"),
        ScreenOperation::PreviousLine(count) => format!("\u{1b}[{count}F"),
        ScreenOperation::Column(column) => format!("\u{1b}[{column}G"),
        ScreenOperation::Position(row, column) => {
            format!("\u{1b}[{row};{column}H")
        }
        ScreenOperation::EraseLine(scope) => format!("\u{1b}[{scope}K"),
        ScreenOperation::EraseDisplay(scope) => format!("\u{1b}[{scope}J"),
        ScreenOperation::Ignored(sequence) => sequence.to_owned(),
    }
}

pub fn show_on_screen(
    size: TerminalSize,
    operations: &[ScreenOperation],
) -> Vec<String> {
    let mut screen = TerminalScreen::new(size);
    screen.feed(&render(operations));
    screen.lines()
}

pub fn show_on_reference(
    size: TerminalSize,
    operations: &[ScreenOperation],
) -> Vec<String> {
    let mut reference = ReferenceScreen::new(size);
    for operation in operations {
        reference.apply(*operation);
    }
    reference.lines()
}

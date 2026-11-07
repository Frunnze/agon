use orchestration_hub::terminal_screen::{
    MAXIMUM_KEPT_LINES, TerminalScreen, TerminalSize,
};
use proptest::prelude::*;
use unicode_width::UnicodeWidthChar;

const SCREEN_SIZE: TerminalSize = TerminalSize {
    columns: 80,
    rows: 24,
};
const ERASE_WHOLE_LINE: &str = "\u{1b}[2K";
const CURSOR_UP_ONE: &str = "\u{1b}[1A";
const CURSOR_TO_FIRST_COLUMN: &str = "\u{1b}[G";
const LINE_BREAK: &str = "\r\n";
const TERMINAL_OUTPUT_PATTERN: &str = concat!(
    "(\\PC|\u{1b}\\[[0-9;?]{0,6}[A-Za-z]",
    "|\u{1b}\\][^\u{7}]{0,8}\u{7}|\r|\n){0,60}",
);

fn count_cells(line: &str, columns: usize) -> usize {
    let mut cells = 0;
    for character in line.chars() {
        let width = character.width().unwrap_or(1);
        cells += width.min(columns);
    }
    cells
}

fn plain_line() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9.,:!?/=-]{0,40}"
}

fn plain_lines() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::vec(plain_line(), 0..12)
}

fn frames() -> impl Strategy<Value = Vec<Vec<String>>> {
    proptest::collection::vec(
        proptest::collection::vec(plain_line(), 1..6),
        1..6,
    )
}

fn show(text: &str) -> Vec<String> {
    let mut screen = TerminalScreen::new(SCREEN_SIZE);
    screen.feed(text);
    screen.lines()
}

fn drop_trailing_empty_lines(lines: &[String]) -> Vec<String> {
    let mut kept = lines.to_vec();
    while kept.last().is_some_and(String::is_empty) {
        kept.pop();
    }
    kept
}

fn erase_previous_frame(previous_frame: &str) -> String {
    let line_count = previous_frame.split('\n').count();
    let mut erasing = String::new();
    for index in 0..line_count {
        erasing.push_str(ERASE_WHOLE_LINE);
        if index + 1 < line_count {
            erasing.push_str(CURSOR_UP_ONE);
        }
    }
    erasing.push_str(CURSOR_TO_FIRST_COLUMN);
    erasing
}

fn redraw_frames(frames: &[Vec<String>]) -> String {
    let mut output = String::new();
    let mut previous_frame: Option<String> = None;
    for frame_lines in frames {
        if let Some(previous) = &previous_frame {
            output.push_str(&erase_previous_frame(previous));
        }
        let frame = format!("{}\n", frame_lines.join("\n"));
        output.push_str(&frame);
        previous_frame = Some(frame);
    }
    output
}

proptest! {
    #[test]
    fn test_feed_property_plain_lines_come_back_unchanged(
        lines in plain_lines(),
    ) {
        let shown = show(&lines.join(LINE_BREAK));

        prop_assert_eq!(shown, drop_trailing_empty_lines(&lines));
    }

    #[test]
    fn test_feed_property_feeding_in_pieces_matches_feeding_at_once(
        text in TERMINAL_OUTPUT_PATTERN,
        split_share in 0.0_f64..1.0,
    ) {
        let characters: Vec<char> = text.chars().collect();
        #[allow(
            clippy::cast_possible_truncation,
            clippy::cast_sign_loss,
            clippy::cast_precision_loss
        )]
        let split_at = (characters.len() as f64 * split_share) as usize;
        let first: String = characters[..split_at].iter().collect();
        let second: String = characters[split_at..].iter().collect();
        let mut pieces = TerminalScreen::new(SCREEN_SIZE);

        pieces.feed(&first);
        pieces.feed(&second);

        prop_assert_eq!(pieces.lines(), show(&text));
    }

    #[test]
    fn test_feed_property_carriage_return_overwrites_the_line(
        old in "[a-z]{0,20}",
        new in "[A-Z]{20,30}",
    ) {
        let shown = show(&format!("{old}\r{new}"));

        prop_assert_eq!(shown, vec![new]);
    }

    #[test]
    fn test_feed_property_redrawn_frames_show_only_the_last_frame(
        frames in frames(),
    ) {
        let shown = show(&redraw_frames(&frames));

        let Some(last_frame) = frames.last() else {
            return Err(TestCaseError::fail("no frame was drawn"));
        };
        prop_assert_eq!(shown, drop_trailing_empty_lines(last_frame));
    }

    #[test]
    fn test_feed_property_long_lines_wrap_at_the_width(
        line in "[a-z]{81,400}",
    ) {
        let shown = show(&line);

        let characters: Vec<char> = line.chars().collect();
        let expected: Vec<String> = characters
            .chunks(usize::from(SCREEN_SIZE.columns))
            .map(|chunk| chunk.iter().collect())
            .collect();
        prop_assert_eq!(shown, expected);
    }

    #[test]
    fn test_feed_property_styles_and_links_leave_only_their_text(
        words in proptest::collection::vec("[a-z]{1,10}", 1..8),
        link in "https://[a-z.]{1,20}",
    ) {
        let mut pieces = Vec::new();
        for word in &words {
            pieces.push(format!(
                "\u{1b}[1;32m\u{1b}]8;;{link}\u{7}{word}\u{1b}]8;;\u{1b}\\\
                 \u{1b}[0m "
            ));
        }
        let styled = pieces.concat();

        let shown = show(&styled);

        prop_assert_eq!(shown, vec![words.join(" ")]);
    }

    #[test]
    fn test_feed_property_arbitrary_output_keeps_the_screen_in_bounds(
        text in "\\PC{0,400}|[\\x00-\\x7f]{0,400}",
        columns in 1_u16..200,
        rows in 1_u16..60,
    ) {
        let mut screen = TerminalScreen::new(TerminalSize { columns, rows });

        screen.feed(&text);

        let lines = screen.lines();
        prop_assert!(lines.len() <= MAXIMUM_KEPT_LINES);
        let columns = usize::from(columns);
        for line in lines {
            prop_assert!(count_cells(&line, columns) <= columns, "{line:?}");
        }
    }

    #[test]
    fn test_feed_property_endless_output_keeps_only_the_newest_lines(
        extra_lines in 1_usize..50,
    ) {
        let line_count = MAXIMUM_KEPT_LINES + extra_lines;
        let mut lines = Vec::new();
        for index in 0..line_count {
            lines.push(format!("line {index}"));
        }
        lines.push("last".to_owned());
        let output = lines.join(LINE_BREAK);

        let shown = show(&output);

        prop_assert_eq!(shown.len(), MAXIMUM_KEPT_LINES);
        prop_assert_eq!(shown.last().map(String::as_str), Some("last"));
    }
}

#[test]
fn erase_to_the_end_of_the_line_keeps_the_start() {
    let shown = show("Paste code here > abc\u{1b}[3D\u{1b}[K");

    assert_eq!(shown, vec!["Paste code here >".to_owned()]);
}

#[test]
fn cursor_positions_count_from_the_top_of_the_screen() {
    let shown = show("first\r\nsecond\u{1b}[1;3HX\u{1b}[2;1HY");

    assert_eq!(shown, vec!["fiXst".to_owned(), "Yecond".to_owned()]);
}

#[test]
fn erasing_the_screen_clears_what_was_shown() {
    let shown = show("old line\r\nmore\u{1b}[2J\u{1b}[Hnew");

    assert_eq!(shown, vec!["new".to_owned()]);
}

#[test]
fn backspace_and_tab_move_the_cursor() {
    let shown = show("abc\u{8}\u{8}X\tY");

    assert_eq!(shown, vec!["aXc     Y".to_owned()]);
}

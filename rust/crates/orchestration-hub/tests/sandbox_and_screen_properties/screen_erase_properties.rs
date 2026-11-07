use orchestration_hub::terminal_screen::{
    MAXIMUM_KEPT_LINES, TerminalScreen, TerminalSize,
};
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::select;

use crate::screen_operations::{
    NARROW_CHARACTERS, ScreenOperation, any_cursor_move, any_erase,
    any_narrow_print, any_operations, any_size, any_unicode_print, render,
    show_on_reference, show_on_screen,
};

const CLEAR_TERMINAL: &str = "\u{1b}[2J\u{1b}[3J\u{1b}[H";
const LINE_SCOPES: [usize; 3] = [0, 1, 2];
const DISPLAY_SCOPES: [usize; 4] = [0, 1, 2, 3];
const MEMORY_CASES: u32 = 24;
const BEYOND_THE_SCREEN: usize = 500;

fn check(
    size: TerminalSize,
    operations: &[ScreenOperation],
) -> Result<(), TestCaseError> {
    let shown = show_on_screen(size, operations);
    prop_assert_eq!(shown, show_on_reference(size, operations));
    Ok(())
}

fn prints(text: &str) -> Vec<ScreenOperation> {
    text.chars().map(ScreenOperation::Print).collect()
}

fn letter_for(index: usize) -> char {
    let letters: Vec<char> = ('a'..='z').collect();
    letters[index % letters.len()]
}

fn any_erasing_operations() -> impl Strategy<Value = Vec<ScreenOperation>> {
    let operation = prop_oneof![
        3 => any_unicode_print(),
        2 => any_cursor_move(),
        2 => any_erase(),
    ];
    vec(operation, 0..60)
}

proptest! {
    #[test]
    fn test_erase_in_line_property_matches_the_reference(
        size in any_size(),
        operations in any_erasing_operations(),
    ) {
        check(size, &operations)?;
    }

    #[test]
    fn test_erase_in_line_property_whole_line_erase_leaves_it_blank(
        size in any_size(),
        operations in any_operations(any_narrow_print()),
        text in "[a-z]{1,10}",
    ) {
        let mut before_text = operations;
        before_text.push(ScreenOperation::Down(BEYOND_THE_SCREEN));
        before_text.push(ScreenOperation::LineFeed);
        let fitting_length = text.len().min(usize::from(size.columns) - 1);
        let mut erased = before_text.clone();
        erased.extend(prints(&text[..fitting_length]));
        erased.push(ScreenOperation::EraseLine(2));

        let shown = show_on_screen(size, &erased);

        prop_assert_eq!(shown, show_on_screen(size, &before_text));
        check(size, &erased)?;
    }

    #[test]
    fn test_erase_in_line_property_erasing_at_a_full_line_erases_the_end(
        size in any_size(),
        filler in select(NARROW_CHARACTERS.to_vec()),
        scope in select(LINE_SCOPES.to_vec()),
    ) {
        let width = usize::from(size.columns);
        let mut operations = vec![ScreenOperation::Print('a'); width - 1];
        operations.push(ScreenOperation::Print(filler));
        operations.push(ScreenOperation::EraseLine(scope));
        operations.push(ScreenOperation::Print('X'));

        check(size, &operations)?;
    }

    #[test]
    fn test_erase_in_display_property_matches_the_reference(
        size in any_size(),
        operations in any_erasing_operations(),
        scope in select(DISPLAY_SCOPES.to_vec()),
    ) {
        let mut operations = operations;
        operations.push(ScreenOperation::EraseDisplay(scope));

        check(size, &operations)?;
    }

    #[test]
    fn test_erase_in_display_property_clearing_the_terminal_shows_new_text(
        size in any_size(),
        operations in any_operations(any_unicode_print()),
        text in "[a-z]{1,10}",
    ) {
        let mut screen = TerminalScreen::new(size);
        screen.feed(&render(&operations));

        screen.feed(CLEAR_TERMINAL);
        screen.feed(&text);

        let fresh = show_on_screen(size, &prints(&text));
        prop_assert_eq!(screen.lines(), fresh);
    }

    #[test]
    fn test_erase_in_display_property_saved_lines_go_but_the_screen_stays(
        size in any_size(),
        operations in any_operations(any_unicode_print()),
    ) {
        let mut operations = operations;
        operations.push(ScreenOperation::EraseDisplay(3));

        let shown = show_on_screen(size, &operations);

        prop_assert!(shown.len() <= usize::from(size.rows));
        check(size, &operations)?;
    }

    #[test]
    fn test_line_under_cursor_property_moving_below_text_adds_blank_lines(
        size in any_size(),
        text in "[a-z]{1,6}",
        row in 1_usize..8,
    ) {
        let mut operations = prints(&text);
        operations.push(ScreenOperation::Position(row, 1));
        operations.push(ScreenOperation::Print('X'));

        check(size, &operations)?;
    }

    #[test]
    fn test_line_under_cursor_property_erasing_empty_rows_adds_nothing(
        size in any_size(),
        row in 1_usize..8,
        scope in select(LINE_SCOPES.to_vec()),
    ) {
        let operations = vec![
            ScreenOperation::Position(row, 1),
            ScreenOperation::EraseLine(scope),
            ScreenOperation::EraseDisplay(scope),
        ];

        let shown = show_on_screen(size, &operations);

        prop_assert_eq!(shown, Vec::<String>::new());
    }

    #[test]
    fn test_line_under_cursor_property_printing_far_right_pads_with_blanks(
        size in any_size(),
        column in 1_usize..14,
    ) {
        let operations = vec![
            ScreenOperation::Column(column),
            ScreenOperation::Print('X'),
        ];

        let shown = show_on_screen(size, &operations);

        let last_column = usize::from(size.columns) - 1;
        let padding = " ".repeat((column - 1).min(last_column));
        prop_assert_eq!(shown, vec![format!("{padding}X")]);
    }

}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(MEMORY_CASES))]

    #[test]
    fn test_forget_oldest_lines_property_keeps_the_newest_suffix(
        size in any_size(),
        extra_lines in 1_usize..40,
        operations in any_operations(any_unicode_print()),
    ) {
        let mut all_operations = Vec::new();
        for index in 0..MAXIMUM_KEPT_LINES + extra_lines {
            all_operations.push(ScreenOperation::Print(letter_for(index)));
            all_operations.push(ScreenOperation::LineFeed);
        }
        all_operations.extend(operations);

        let shown = show_on_screen(size, &all_operations);
        let reference = show_on_reference(size, &all_operations);

        prop_assert!(shown.len() <= MAXIMUM_KEPT_LINES);
        prop_assert!(reference.ends_with(&shown));
    }

    #[test]
    fn test_forget_oldest_lines_property_screen_survives_the_trim(
        size in any_size(),
        extra_lines in 1_usize..40,
        row in 1_usize..8,
    ) {
        let mut operations = Vec::new();
        for _ in 0..MAXIMUM_KEPT_LINES + extra_lines {
            operations.push(ScreenOperation::Print('l'));
            operations.push(ScreenOperation::LineFeed);
        }
        operations.push(ScreenOperation::Position(row, 1));
        operations.push(ScreenOperation::Print('X'));

        let shown = show_on_screen(size, &operations);
        let reference = show_on_reference(size, &operations);

        prop_assert!(reference.ends_with(&shown));
        prop_assert!(shown.iter().any(|line| line.starts_with('X')));
    }

    #[test]
    fn test_forget_oldest_lines_property_one_feed_matches_many(
        size in any_size(),
        extra_lines in 1_usize..40,
    ) {
        let mut text = String::new();
        for _ in 0..MAXIMUM_KEPT_LINES + extra_lines {
            text.push_str("line\n");
        }
        let mut in_pieces = TerminalScreen::new(size);
        for line in text.split_inclusive('\n') {
            in_pieces.feed(line);
        }

        let mut at_once = TerminalScreen::new(size);
        at_once.feed(&text);

        let kept_count = at_once.lines().len();
        prop_assert_eq!(in_pieces.lines(), at_once.lines());
        prop_assert!(kept_count <= MAXIMUM_KEPT_LINES);
        prop_assert!(kept_count + 1 >= MAXIMUM_KEPT_LINES);
    }
}

use orchestration_hub::terminal_screen::TerminalSize;
use proptest::prelude::*;
use proptest::sample::select;

use crate::screen_operations::{
    MARK_CHARACTERS, NARROW_CHARACTERS, ScreenOperation, WIDE_CHARACTERS,
    any_operations, any_size, any_unicode_print, show_on_reference,
    show_on_screen,
};

const SAVED_LINES_SCOPE: usize = 3;
const LEFT_HALF_SCOPE: usize = 1;

fn check(
    size: TerminalSize,
    operations: &[ScreenOperation],
) -> Result<(), TestCaseError> {
    let shown = show_on_screen(size, operations);
    prop_assert_eq!(shown, show_on_reference(size, operations));
    Ok(())
}

fn any_wide() -> impl Strategy<Value = char> {
    select(WIDE_CHARACTERS.to_vec())
}

fn any_mark() -> impl Strategy<Value = char> {
    select(MARK_CHARACTERS.to_vec())
}

fn blank_feeds(count: usize) -> Vec<ScreenOperation> {
    vec![ScreenOperation::LineFeed; count]
}

proptest! {
    #[test]
    fn test_attach_mark_property_marks_join_the_previous_character(
        size in any_size(),
        base in select(NARROW_CHARACTERS.to_vec()),
        mark in any_mark(),
    ) {
        prop_assume!(base != ' ');
        let operations = vec![
            ScreenOperation::Print(base),
            ScreenOperation::Print(mark),
            ScreenOperation::Print('x'),
        ];

        let shown = show_on_screen(size, &operations);

        prop_assert_eq!(shown, vec![format!("{base}{mark}x")]);
    }

    #[test]
    fn test_attach_mark_property_marks_at_the_line_start_are_dropped(
        size in any_size(),
        mark in any_mark(),
        text in "[a-z]{0,6}",
    ) {
        let mut operations: Vec<ScreenOperation> =
            text.chars().map(ScreenOperation::Print).collect();
        operations.push(ScreenOperation::CarriageReturn);
        operations.push(ScreenOperation::Print(mark));

        let shown = show_on_screen(size, &operations);

        let without_mark = show_on_screen(size, &operations[..text.len()]);
        prop_assert_eq!(shown, without_mark);
    }

    #[test]
    fn test_attach_mark_property_full_line_marks_join_the_last_cell(
        size in any_size(),
        filler in select(NARROW_CHARACTERS.to_vec()),
        mark in any_mark(),
    ) {
        let width = usize::from(size.columns);
        let mut operations = vec![ScreenOperation::Print(filler); width];
        operations.push(ScreenOperation::Print(mark));
        operations.push(ScreenOperation::Print('x'));

        check(size, &operations)?;
    }

    #[test]
    fn test_erase_saved_lines_property_keeps_only_the_visible_rows(
        size in any_size(),
        operations in any_operations(any_unicode_print()),
    ) {
        let mut operations = operations;
        operations.push(ScreenOperation::EraseDisplay(SAVED_LINES_SCOPE));

        let shown = show_on_screen(size, &operations);

        prop_assert!(shown.len() <= usize::from(size.rows));
        check(size, &operations)?;
    }

    #[test]
    fn test_erase_saved_lines_property_cursor_keeps_its_screen_row(
        size in any_size(),
        line_count in 0_usize..20,
    ) {
        let mut operations = Vec::new();
        for _ in 0..line_count {
            operations.push(ScreenOperation::Print('l'));
            operations.push(ScreenOperation::LineFeed);
        }
        operations.push(ScreenOperation::EraseDisplay(SAVED_LINES_SCOPE));
        operations.push(ScreenOperation::Print('X'));

        check(size, &operations)?;
    }

    #[test]
    fn test_erase_saved_lines_property_erasing_twice_is_erasing_once(
        size in any_size(),
        operations in any_operations(any_unicode_print()),
    ) {
        let mut once = operations;
        once.push(ScreenOperation::EraseDisplay(SAVED_LINES_SCOPE));
        let mut twice = once.clone();
        twice.push(ScreenOperation::EraseDisplay(SAVED_LINES_SCOPE));

        let shown_once = show_on_screen(size, &once);

        prop_assert_eq!(shown_once, show_on_screen(size, &twice));
    }

    #[test]
    fn test_keep_cursor_line_property_blank_scrolls_stay_scrolled(
        size in any_size(),
        feed_count in 1_usize..12,
        up_count in 0_usize..8,
    ) {
        let mut operations = vec![ScreenOperation::Print('a')];
        operations.extend(blank_feeds(feed_count));
        operations.push(ScreenOperation::Up(up_count));
        operations.push(ScreenOperation::Print('X'));

        check(size, &operations)?;
    }

    #[test]
    fn test_keep_cursor_line_property_blank_feeds_count_as_lines(
        size in any_size(),
        feed_count in 0_usize..12,
    ) {
        let mut operations = vec![ScreenOperation::Print('a')];
        operations.extend(blank_feeds(feed_count));
        operations.push(ScreenOperation::Print('b'));

        let shown = show_on_screen(size, &operations);

        prop_assert_eq!(shown.len(), feed_count + 1);
        prop_assert!(shown.first().is_some_and(|line| line.starts_with('a')));
        prop_assert!(shown.last().is_some_and(|line| line.ends_with('b')));
    }

    #[test]
    fn test_keep_cursor_line_property_home_after_blank_scrolls_is_on_screen(
        size in any_size(),
        feed_count in 0_usize..12,
        row in 0_usize..8,
    ) {
        let mut operations = vec![ScreenOperation::Print('a')];
        operations.extend(blank_feeds(feed_count));
        operations.push(ScreenOperation::Position(row, 1));
        operations.push(ScreenOperation::Print('X'));

        check(size, &operations)?;
    }

    #[test]
    fn test_clear_broken_halves_property_right_half_writes_blank_the_left(
        size in any_size(),
        wide in any_wide(),
    ) {
        let operations = vec![
            ScreenOperation::Print(wide),
            ScreenOperation::Column(2),
            ScreenOperation::Print('x'),
        ];

        let shown = show_on_screen(size, &operations);

        prop_assert_eq!(shown, vec![" x".to_owned()]);
    }

    #[test]
    fn test_clear_broken_halves_property_left_half_writes_blank_the_right(
        size in any_size(),
        wide in any_wide(),
        tail in "[a-z]{0,4}",
    ) {
        let mut operations = vec![ScreenOperation::Print(wide)];
        operations.extend(tail.chars().map(ScreenOperation::Print));
        operations.push(ScreenOperation::CarriageReturn);
        operations.push(ScreenOperation::Print('x'));

        check(size, &operations)?;
    }

    #[test]
    fn test_clear_broken_halves_property_erasing_half_erases_it_all(
        size in any_size(),
        first in any_wide(),
        second in any_wide(),
        column in 1_usize..5,
    ) {
        let operations = vec![
            ScreenOperation::Print(first),
            ScreenOperation::Print(second),
            ScreenOperation::Column(column),
            ScreenOperation::EraseLine(LEFT_HALF_SCOPE),
        ];

        let shown = show_on_screen(size, &operations);

        let fits_on_one_line = size.columns >= 4;
        let is_on_first_character = fits_on_one_line && column <= 2;
        if is_on_first_character && first != second {
            let first_text = first.to_string();
            prop_assert!(!shown.concat().contains(&first_text), "{shown:?}");
        }
        check(size, &operations)?;
    }
}

use orchestration_hub::terminal_screen::{TerminalScreen, TerminalSize};
use proptest::prelude::*;
use proptest::sample::select;

use crate::screen_operations::{
    IGNORED_SEQUENCES, NARROW_CHARACTERS, ScreenOperation, WIDE_CHARACTERS,
    any_cursor_move, any_narrow_print, any_operations, any_size,
    any_unicode_print, render, show_on_reference, show_on_screen,
};

fn prints(text: &str) -> Vec<ScreenOperation> {
    text.chars().map(ScreenOperation::Print).collect()
}

fn without_ignored(operations: &[ScreenOperation]) -> Vec<ScreenOperation> {
    operations
        .iter()
        .filter(|operation| !matches!(operation, ScreenOperation::Ignored(_)))
        .copied()
        .collect()
}

fn any_line_text() -> impl Strategy<Value = String> {
    let mut characters = NARROW_CHARACTERS.to_vec();
    characters.extend(WIDE_CHARACTERS);
    proptest::collection::vec(select(characters), 0..40)
        .prop_map(|characters| characters.into_iter().collect())
}

proptest! {
    #[test]
    fn test_apply_property_matches_the_reference_screen(
        size in any_size(),
        operations in any_operations(any_narrow_print()),
    ) {
        let shown = show_on_screen(size, &operations);

        prop_assert_eq!(shown, show_on_reference(size, &operations));
    }

    #[test]
    fn test_apply_property_matches_the_reference_with_wide_characters(
        size in any_size(),
        operations in any_operations(any_unicode_print()),
    ) {
        let shown = show_on_screen(size, &operations);

        prop_assert_eq!(shown, show_on_reference(size, &operations));
    }

    #[test]
    fn test_apply_property_styles_and_titles_change_nothing(
        size in any_size(),
        operations in any_operations(any_unicode_print()),
    ) {
        let shown = show_on_screen(size, &operations);

        let plain = without_ignored(&operations);
        prop_assert_eq!(shown, show_on_screen(size, &plain));
    }

    #[test]
    fn test_print_property_long_text_wraps_like_a_terminal(
        size in any_size(),
        text in any_line_text(),
    ) {
        let operations = prints(&text);

        let shown = show_on_screen(size, &operations);

        prop_assert_eq!(shown, show_on_reference(size, &operations));
    }

    #[test]
    fn test_print_property_a_full_line_waits_before_wrapping(
        size in any_size(),
        filler in select(NARROW_CHARACTERS.to_vec()),
        moving in any_cursor_move(),
        last in select(vec!['X', '中']),
    ) {
        let width = usize::from(size.columns);
        let mut operations = vec![ScreenOperation::Print(filler); width];
        operations.push(moving);
        operations.push(ScreenOperation::Print(last));

        let shown = show_on_screen(size, &operations);

        prop_assert_eq!(shown, show_on_reference(size, &operations));
    }

    #[test]
    fn test_print_property_overwriting_cells_matches_the_reference(
        size in any_size(),
        first in any_line_text(),
        second in any_line_text(),
        column in 0_usize..12,
    ) {
        let mut operations = prints(&first);
        operations.push(ScreenOperation::Column(column));
        operations.extend(prints(&second));

        let shown = show_on_screen(size, &operations);

        prop_assert_eq!(shown, show_on_reference(size, &operations));
    }

    #[test]
    fn test_terminal_screen_new_property_starts_without_lines(
        columns in any::<u16>(),
        rows in any::<u16>(),
    ) {
        let screen = TerminalScreen::new(TerminalSize { columns, rows });

        prop_assert_eq!(screen.lines(), Vec::<String>::new());
    }

    #[test]
    fn test_terminal_screen_new_property_zero_sizes_act_as_one(
        operations in any_operations(any_narrow_print()),
    ) {
        let zero = TerminalSize { columns: 0, rows: 0 };
        let one = TerminalSize { columns: 1, rows: 1 };

        let shown = show_on_screen(zero, &operations);

        prop_assert_eq!(shown, show_on_screen(one, &operations));
    }

    #[test]
    fn test_terminal_screen_new_property_columns_set_the_wrap_width(
        size in any_size(),
        text in "[a-z]{0,60}",
    ) {
        let shown = show_on_screen(size, &prints(&text));

        let characters: Vec<char> = text.chars().collect();
        let expected: Vec<String> = characters
            .chunks(usize::from(size.columns))
            .map(|chunk| chunk.iter().collect())
            .collect();
        prop_assert_eq!(shown, expected);
    }

    #[test]
    fn test_lines_property_never_end_in_blanks(
        size in any_size(),
        operations in any_operations(any_unicode_print()),
    ) {
        let shown = show_on_screen(size, &operations);

        prop_assert!(shown.last().is_none_or(|line| !line.is_empty()));
        for line in &shown {
            prop_assert_eq!(line.trim_end(), line.as_str());
        }
    }

    #[test]
    fn test_lines_property_hold_no_control_characters(
        size in any_size(),
        operations in any_operations(any_unicode_print()),
    ) {
        let shown = show_on_screen(size, &operations);

        for line in &shown {
            prop_assert!(!line.chars().any(char::is_control), "{line:?}");
        }
    }

    #[test]
    fn test_lines_property_reading_changes_nothing(
        size in any_size(),
        operations in any_operations(any_unicode_print()),
        ignored in select(IGNORED_SEQUENCES.to_vec()),
    ) {
        let mut screen = TerminalScreen::new(size);
        screen.feed(&render(&operations));

        let first_read = screen.lines();
        screen.feed("");
        screen.feed(ignored);

        prop_assert_eq!(screen.lines(), first_read);
    }
}

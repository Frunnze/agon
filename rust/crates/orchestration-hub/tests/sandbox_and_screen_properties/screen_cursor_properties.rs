use orchestration_hub::terminal_screen::TerminalSize;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::select;

use crate::screen_operations::{
    NARROW_CHARACTERS, ScreenOperation, any_narrow_print, any_size,
    any_unicode_print, show_on_reference, show_on_screen,
};

const FAR: usize = 500;

fn any_vertical_moves() -> impl Strategy<Value = Vec<ScreenOperation>> {
    let operation = prop_oneof![
        3 => any_unicode_print(),
        1 => Just(ScreenOperation::LineFeed),
        1 => (0_usize..8).prop_map(ScreenOperation::Up),
        1 => (0_usize..8).prop_map(ScreenOperation::Down),
        1 => (0_usize..4).prop_map(ScreenOperation::NextLine),
        1 => (0_usize..4).prop_map(ScreenOperation::PreviousLine),
    ];
    vec(operation, 0..60)
}

fn any_horizontal_moves() -> impl Strategy<Value = Vec<ScreenOperation>> {
    let operation = prop_oneof![
        3 => any_unicode_print(),
        1 => Just(ScreenOperation::Backspace),
        1 => Just(ScreenOperation::Tab),
        1 => Just(ScreenOperation::CarriageReturn),
        1 => (0_usize..14).prop_map(ScreenOperation::Forward),
        1 => (0_usize..14).prop_map(ScreenOperation::Back),
        1 => (0_usize..14).prop_map(ScreenOperation::Column),
    ];
    vec(operation, 0..60)
}

fn lines_of(count: usize) -> Vec<ScreenOperation> {
    let mut operations = Vec::new();
    for _ in 0..count {
        operations.push(ScreenOperation::Print('l'));
        operations.push(ScreenOperation::LineFeed);
    }
    operations
}

fn check(
    size: TerminalSize,
    operations: &[ScreenOperation],
) -> Result<(), TestCaseError> {
    let shown = show_on_screen(size, operations);
    prop_assert_eq!(shown, show_on_reference(size, operations));
    Ok(())
}

proptest! {
    #[test]
    fn test_move_up_property_matches_the_reference(
        size in any_size(),
        operations in any_vertical_moves(),
    ) {
        check(size, &operations)?;
    }

    #[test]
    fn test_move_up_property_stops_at_the_screen_top(
        size in any_size(),
        line_count in 0_usize..12,
    ) {
        let mut operations = lines_of(line_count);
        operations.push(ScreenOperation::Up(FAR));
        operations.push(ScreenOperation::Print('X'));

        check(size, &operations)?;
    }

    #[test]
    fn test_move_up_property_previous_line_goes_to_the_line_start(
        size in any_size(),
        operations in any_vertical_moves(),
        count in 0_usize..4,
    ) {
        let mut operations = operations;
        operations.push(ScreenOperation::PreviousLine(count));
        operations.push(ScreenOperation::Print('X'));

        check(size, &operations)?;
    }

    #[test]
    fn test_move_down_property_matches_the_reference(
        size in any_size(),
        operations in any_vertical_moves(),
        horizontal in any_horizontal_moves(),
    ) {
        let mut operations = operations;
        operations.extend(horizontal);

        check(size, &operations)?;
    }

    #[test]
    fn test_move_down_property_stops_at_the_screen_bottom(
        size in any_size(),
        line_count in 0_usize..12,
    ) {
        let mut operations = lines_of(line_count);
        operations.push(ScreenOperation::Down(FAR));
        operations.push(ScreenOperation::Print('X'));

        let shown = show_on_screen(size, &operations);

        let rows = usize::from(size.rows);
        prop_assert_eq!(shown.len(), rows.max(line_count + 1));
        check(size, &operations)?;
    }

    #[test]
    fn test_move_down_property_never_scrolls(
        size in any_size(),
        text in "[a-z]{1,6}",
    ) {
        let mut operations = Vec::new();
        let width = usize::from(size.columns);
        for character in text.chars().take(width) {
            operations.push(ScreenOperation::Print(character));
            operations.push(ScreenOperation::Down(FAR));
        }

        let shown = show_on_screen(size, &operations);

        prop_assert!(shown.len() <= usize::from(size.rows));
        check(size, &operations)?;
    }

    #[test]
    fn test_move_to_line_start_property_line_feed_starts_a_fresh_line(
        size in any_size(),
        operations in any_horizontal_moves(),
    ) {
        let mut operations = operations;
        operations.push(ScreenOperation::LineFeed);
        operations.push(ScreenOperation::Print('X'));

        let shown = show_on_screen(size, &operations);

        prop_assert!(shown.last().is_some_and(|line| line.starts_with('X')));
        check(size, &operations)?;
    }

    #[test]
    fn test_move_to_line_start_property_full_line_then_feed_moves_once(
        size in any_size(),
        filler in select(NARROW_CHARACTERS.to_vec()),
    ) {
        let width = usize::from(size.columns);
        let mut operations = vec![ScreenOperation::Print(filler); width];
        operations.push(ScreenOperation::LineFeed);
        operations.push(ScreenOperation::Print('X'));

        check(size, &operations)?;
    }

    #[test]
    fn test_move_to_line_start_property_scrolls_at_the_bottom(
        size in any_size(),
        line_count in 0_usize..20,
    ) {
        let mut operations = lines_of(line_count);
        operations.push(ScreenOperation::Print('X'));

        let shown = show_on_screen(size, &operations);

        prop_assert_eq!(shown.len(), line_count + 1);
        check(size, &operations)?;
    }

    #[test]
    fn test_find_screen_top_property_home_is_the_first_visible_row(
        size in any_size(),
        line_count in 0_usize..20,
        row in 0_usize..8,
        column in 0_usize..14,
    ) {
        let mut operations = lines_of(line_count);
        operations.push(ScreenOperation::Position(row, column));
        operations.push(ScreenOperation::Print('X'));

        check(size, &operations)?;
    }

    #[test]
    fn test_find_screen_top_property_positions_never_reach_saved_lines(
        size in any_size(),
        line_count in 0_usize..20,
    ) {
        let mut operations = lines_of(line_count);
        operations.push(ScreenOperation::Position(1, 1));
        operations.push(ScreenOperation::Print('X'));

        let shown = show_on_screen(size, &operations);

        let rows = usize::from(size.rows);
        let saved_count = (line_count + 1).saturating_sub(rows);
        for saved_line in &shown[..saved_count.min(shown.len())] {
            prop_assert_eq!(saved_line.as_str(), "l");
        }
        check(size, &operations)?;
    }

    #[test]
    fn test_find_screen_top_property_mixed_moves_match_the_reference(
        size in any_size(),
        vertical in any_vertical_moves(),
        horizontal in any_horizontal_moves(),
        row in 0_usize..8,
    ) {
        let mut operations = vertical;
        operations.push(ScreenOperation::Position(row, 1));
        operations.extend(horizontal);

        check(size, &operations)?;
    }

    #[test]
    fn test_last_column_property_far_moves_stop_at_the_last_column(
        size in any_size(),
        far_move in select(vec![
            ScreenOperation::Forward(FAR),
            ScreenOperation::Column(FAR),
            ScreenOperation::Position(1, FAR),
        ]),
    ) {
        let operations = vec![far_move, ScreenOperation::Print('X')];

        let shown = show_on_screen(size, &operations);

        let width = usize::from(size.columns);
        let expected = format!("{}X", " ".repeat(width - 1));
        prop_assert_eq!(shown, vec![expected]);
    }

    #[test]
    fn test_last_column_property_tabs_stop_at_the_last_column(
        size in any_size(),
        tab_count in 1_usize..6,
        operations in vec(any_narrow_print(), 0..10),
    ) {
        let mut operations = operations;
        operations.extend(vec![ScreenOperation::Tab; tab_count]);
        operations.push(ScreenOperation::Print('X'));

        check(size, &operations)?;
    }

    #[test]
    fn test_last_column_property_horizontal_moves_match_the_reference(
        size in any_size(),
        operations in any_horizontal_moves(),
    ) {
        check(size, &operations)?;
    }
}

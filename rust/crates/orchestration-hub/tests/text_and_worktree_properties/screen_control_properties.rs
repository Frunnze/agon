use proptest::prelude::*;

use crate::screen_support::{
    ESCAPE, WIDE_SIZE, any_plain_text, show, shown_alone,
};

const LAST_COLUMN: usize = WIDE_SIZE.columns as usize - 1;
const STILL_FINALS: &str = "@ILMNPSTXZ^`abcdeghijklmnopqrstuvwxyz{|}~";

fn any_finished_sequence() -> impl Strategy<Value = String> {
    ("[0-9;:<=>?]{0,12}", "[ -/]{0,2}", "[@-~]").prop_map(
        |(parameters, intermediates, final_character)| {
            format!("{ESCAPE}[{parameters}{intermediates}{final_character}")
        },
    )
}

fn any_still_final() -> impl Strategy<Value = char> {
    let still_finals: Vec<char> = STILL_FINALS.chars().collect();
    proptest::sample::select(still_finals)
}

fn any_cursor_final() -> impl Strategy<Value = char> {
    proptest::sample::select(vec!['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'])
}

fn erase_to_end_of(text: &str, column: usize) -> String {
    text.chars().take(column).collect()
}

fn blank_start_of(text: &str, column: usize) -> String {
    let length = text.chars().count();
    let blanked = (column + 1).min(length);
    let kept: String = text.chars().skip(blanked).collect();
    format!("{}{kept}", " ".repeat(blanked))
}

proptest! {
    #[test]
    fn test_read_control_sequence_property_sequences_never_print(
        (start, sequence) in ("[a-z]{0,10}", any_finished_sequence()),
    ) {
        let output = format!("{start}{sequence}");

        let shown = show(&output);

        let printed: String = shown.concat();
        prop_assert!(printed.trim().chars().all(|character| {
            character.is_ascii_lowercase() || character == ' '
        }), "{:?}", shown);
    }

    #[test]
    fn test_read_control_sequence_property_long_parameters_stay_hidden(
        parameter_count in 0_usize..200,
        final_character in any_still_final(),
        after in any_plain_text(),
    ) {
        let parameters = "1;".repeat(parameter_count);
        let output = format!("{ESCAPE}[{parameters}{final_character}{after}");

        prop_assert_eq!(show(&output), shown_alone(&after));
    }

    #[test]
    fn test_read_control_sequence_property_the_final_byte_ends_it(
        parameters in "[0-9;]{0,8}",
        after in any_plain_text(),
    ) {
        let output = format!("{ESCAPE}[{parameters}m{after}");

        prop_assert_eq!(show(&output), shown_alone(&after));
    }

    #[test]
    fn test_describe_control_sequence_property_relative_moves_shift_text(
        start in "[a-z]{1,30}",
        count in 1_usize..40,
    ) {
        let length = start.chars().count();
        let forward = show(&format!("{start}{ESCAPE}[{count}CX"));
        let back = show(&format!("{start}{ESCAPE}[{count}DX"));

        let gap = " ".repeat(count);
        prop_assert_eq!(forward, vec![format!("{start}{gap}X")]);
        let column = length.saturating_sub(count);
        let mut overwritten: Vec<char> = start.chars().collect();
        overwritten[column] = 'X';
        prop_assert_eq!(
            back,
            vec![overwritten.into_iter().collect::<String>()]
        );
    }

    #[test]
    fn test_describe_control_sequence_property_absolute_moves_are_one_based(
        row in 1_usize..20,
        column in 1_usize..100,
        final_character in prop_oneof![Just('H'), Just('f')],
    ) {
        let output = format!("{ESCAPE}[{row};{column}{final_character}X");

        let shown = show(&output);

        let mut expected = vec![String::new(); row];
        expected[row - 1] = format!("{}X", " ".repeat(column - 1));
        prop_assert_eq!(shown, expected);
    }

    #[test]
    fn test_describe_control_sequence_property_marked_sequences_never_move(
        start in "[a-z]{1,20}",
        marker in prop_oneof![
            "[?<=>][0-9]{0,3}".boxed(),
            "[0-9]{0,3}[ !\"#$%&'()*+,./-]".boxed(),
        ],
        final_character in any_cursor_final(),
        after in "[a-z]{1,10}",
    ) {
        let output =
            format!("{start}{ESCAPE}[{marker}{final_character}{after}");

        prop_assert_eq!(show(&output), vec![format!("{start}{after}")]);
    }

    #[test]
    fn test_read_count_property_zero_and_missing_counts_mean_one(
        start in "[a-z]{2,20}",
        final_character in prop_oneof![Just('C'), Just('D'), Just('G')],
    ) {
        let missing = show(&format!("{start}{ESCAPE}[{final_character}X"));
        let zero = show(&format!("{start}{ESCAPE}[0{final_character}X"));
        let one = show(&format!("{start}{ESCAPE}[1{final_character}X"));

        prop_assert_eq!(&missing, &one);
        prop_assert_eq!(&zero, &one);
    }

    #[test]
    fn test_read_count_property_large_counts_stop_at_the_edge(
        start in "[a-z]{0,20}",
        count in 200_usize..1_000_000,
    ) {
        let output = format!("{start}{ESCAPE}[{count}CX");

        let shown = show(&output);

        let gap = " ".repeat(LAST_COLUMN - start.chars().count());
        prop_assert_eq!(shown, vec![format!("{start}{gap}X")]);
    }

    #[test]
    fn test_read_count_property_a_missing_column_means_the_first(
        row in 1_usize..20,
        separator in prop_oneof![Just(""), Just(";"), Just(";0")],
    ) {
        let output = format!("{ESCAPE}[{row}{separator}HX");

        let shown = show(&output);

        prop_assert_eq!(shown.len(), row);
        prop_assert_eq!(&shown[row - 1], "X");
    }

    #[test]
    fn test_read_scope_property_erase_in_line_follows_the_scope(
        text in "[a-z]{1,30}",
        back in 1_usize..30,
    ) {
        let column = text.chars().count().saturating_sub(back);
        let moved = format!("{text}{ESCAPE}[{back}D");
        let to_end = show(&format!("{moved}{ESCAPE}[K"));
        let to_end_zero = show(&format!("{moved}{ESCAPE}[0K"));
        let to_start = show(&format!("{moved}{ESCAPE}[1K"));
        let whole = show(&format!("{moved}{ESCAPE}[2K"));

        prop_assert_eq!(
            &to_end,
            &shown_alone(&erase_to_end_of(&text, column))
        );
        prop_assert_eq!(&to_end_zero, &to_end);
        prop_assert_eq!(to_start, shown_alone(&blank_start_of(&text, column)));
        prop_assert_eq!(whole, Vec::<String>::new());
    }

    #[test]
    fn test_read_scope_property_erase_in_display_clears_whole_screen(
        lines in proptest::collection::vec("[a-z]{1,10}", 1..10),
    ) {
        let output = lines.join("\n");
        let cleared = show(&format!("{output}{ESCAPE}[2J"));
        let saved_lines_erased = show(&format!("{output}{ESCAPE}[3J"));

        prop_assert_eq!(cleared, Vec::<String>::new());
        prop_assert_eq!(saved_lines_erased, lines);
    }

    #[test]
    fn test_read_scope_property_unknown_scopes_erase_nothing(
        text in "[a-z]{1,30}",
        scope in 4_usize..1000,
        final_character in prop_oneof![Just('J'), Just('K')],
    ) {
        let output = format!("{text}{ESCAPE}[{scope}{final_character}");

        prop_assert_eq!(show(&output), vec![text]);
    }
}

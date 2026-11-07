use proptest::prelude::*;
use proptest::sample::Index;

use crate::screen_support::{
    any_plain_text, any_still_sequence, show, show_in_pieces, shown_alone,
};
use crate::text_shapes::{any_code_placements, insert_codes};

const TAB_WIDTH: usize = 8;
const BACKSPACE: char = '\u{8}';
const INVISIBLE_CONTROLS: [char; 10] = [
    '\u{0}', '\u{1}', '\u{2}', '\u{3}', '\u{5}', '\u{7}', '\u{e}', '\u{1f}',
    '\u{7f}', '\u{90}',
];

fn any_invisible_control() -> impl Strategy<Value = String> {
    proptest::sample::select(INVISIBLE_CONTROLS.to_vec())
        .prop_map(String::from)
}

fn any_noisy_output() -> impl Strategy<Value = String> {
    let piece = prop_oneof![
        any_plain_text(),
        any_still_sequence(),
        Just("\r\n".to_owned()),
        Just("\u{1b}[3D".to_owned()),
        Just("\u{1b}".to_owned()),
        Just("\u{1b}[".to_owned()),
        Just("\u{1b}]".to_owned()),
        Just("\t".to_owned()),
    ];
    proptest::collection::vec(piece, 0..12).prop_map(|pieces| pieces.concat())
}

fn split_at_places(text: &str, places: &[Index]) -> Vec<String> {
    let characters: Vec<char> = text.chars().collect();
    let mut cuts: Vec<usize> = Vec::new();
    for place in places {
        cuts.push(place.index(characters.len() + 1));
    }
    cuts.sort_unstable();

    let mut pieces = Vec::new();
    let mut start = 0;
    for cut in cuts {
        pieces.push(characters[start..cut].iter().collect());
        start = cut;
    }
    pieces.push(characters[start..].iter().collect());
    pieces
}

proptest! {
    #[test]
    fn test_sequence_reader_read_property_pieces_read_like_the_whole(
        output in any_noisy_output(),
        places in proptest::collection::vec(any::<Index>(), 0..6),
    ) {
        let pieces = split_at_places(&output, &places);

        prop_assert_eq!(show_in_pieces(&pieces), show(&output));
    }

    #[test]
    fn test_sequence_reader_read_property_plain_lines_show_as_written(
        lines in proptest::collection::vec(any_plain_text(), 0..8),
    ) {
        let shown = show(&lines.join("\n"));

        let mut expected: Vec<String> =
            lines.iter().map(|line| line.trim_end().to_owned()).collect();
        while expected.last().is_some_and(String::is_empty) {
            expected.pop();
        }
        prop_assert_eq!(shown, expected);
    }

    #[test]
    fn test_sequence_reader_read_property_shown_text_holds_no_controls(
        output in any::<String>(),
    ) {
        let shown = show(&output);

        for line in shown {
            prop_assert!(!line.chars().any(char::is_control), "{:?}", line);
        }
    }

    #[test]
    fn test_read_text_property_unknown_controls_are_invisible(
        text in any_plain_text(),
        placements in any_code_placements(any_invisible_control()),
    ) {
        let noisy = insert_codes(&text, &placements);

        prop_assert_eq!(show(&noisy), show(&text));
        prop_assert_eq!(show(&text), shown_alone(&text));
    }

    #[test]
    fn test_read_text_property_carriage_return_writes_from_line_start(
        first in "[a-z]{0,20}",
        second in "[A-Z]{0,20}",
    ) {
        let shown = show(&format!("{first}\r{second}"));

        let kept_end: String =
            first.chars().skip(second.chars().count()).collect();
        prop_assert_eq!(shown, shown_alone(&format!("{second}{kept_end}")));
    }

    #[test]
    fn test_read_text_property_backspace_and_tab_move_the_cursor(
        start in "[a-z]{1,20}",
        replacement in "[A-Z]",
        after_tab in "[a-z]{1,10}",
    ) {
        let backed = show(&format!("{start}{BACKSPACE}{replacement}"));
        let tabbed = show(&format!("{start}\t{after_tab}"));

        let start_length = start.chars().count();
        let mut overwritten: String =
            start.chars().take(start_length - 1).collect();
        overwritten.push_str(&replacement);
        prop_assert_eq!(backed, vec![overwritten]);
        let next_stop = (start_length / TAB_WIDTH + 1) * TAB_WIDTH;
        let padding = " ".repeat(next_stop - start_length);
        prop_assert_eq!(tabbed, vec![format!("{start}{padding}{after_tab}")]);
    }
}

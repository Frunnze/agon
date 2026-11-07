use proptest::prelude::*;

use crate::screen_support::{ESCAPE, WIDE_SIZE, show};

const SCREEN_ROWS: usize = WIDE_SIZE.rows as usize;

fn numbered_lines(count: usize) -> Vec<String> {
    let mut lines = Vec::new();
    for number in 1..=count {
        lines.push(format!("line {number}"));
    }
    lines
}

proptest! {
    #[test]
    fn test_read_display_erase_property_saved_lines_go_screen_stays(
        extra_lines in 1_usize..40,
    ) {
        let lines = numbered_lines(SCREEN_ROWS + extra_lines);
        let output = format!("{}{ESCAPE}[3J", lines.join("\n"));

        let shown = show(&output);

        prop_assert_eq!(shown, lines[extra_lines..].to_vec());
    }

    #[test]
    fn test_read_display_erase_property_erasing_below_keeps_lines_above(
        line_count in 2_usize..20,
        moved_up in 1_usize..20,
        scope in prop_oneof![Just(""), Just("0")],
    ) {
        prop_assume!(moved_up < line_count);
        let lines = numbered_lines(line_count);
        let output = format!(
            "{}{ESCAPE}[{moved_up}F{ESCAPE}[{scope}J",
            lines.join("\n"),
        );

        let shown = show(&output);

        let kept = line_count - 1 - moved_up;
        prop_assert_eq!(shown, lines[..kept].to_vec());
    }

    #[test]
    fn test_read_display_erase_property_erasing_above_keeps_lines_below(
        line_count in 2_usize..20,
        moved_up in 1_usize..20,
    ) {
        prop_assume!(moved_up < line_count);
        let lines = numbered_lines(line_count);
        let output = format!(
            "{}{ESCAPE}[{moved_up}F{ESCAPE}[1J",
            lines.join("\n"),
        );

        let shown = show(&output);

        let cursor_row = line_count - 1 - moved_up;
        let mut expected = vec![String::new(); cursor_row];
        let cursor_line: String = lines[cursor_row].chars().skip(1).collect();
        expected.push(format!(" {cursor_line}").trim_end().to_owned());
        expected.extend_from_slice(&lines[cursor_row + 1..]);
        prop_assert_eq!(shown, expected);
    }
}

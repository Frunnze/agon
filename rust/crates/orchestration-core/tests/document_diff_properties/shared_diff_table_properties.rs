use orchestration_core::document_diff::{DiffLine, diff_lines};
use proptest::collection::vec;
use proptest::prelude::*;
use serde::Deserialize;

const SHARED_DIFF_TABLE: &str =
    include_str!("../fixtures/document_diff_cases.json");
const LINE_TEXT: &str = "[a-z: \\-]{0,12}";
const INDENTATION: &str = "[ \t\u{3000}\u{a0}]{0,6}";
const LARGEST_LINE_COUNT: usize = 8;

#[derive(Debug, Deserialize)]
struct SharedDiffTable {
    cases: Vec<SharedDiffCase>,
}

#[derive(Debug, Deserialize)]
struct SharedDiffCase {
    name: String,
    previous: String,
    current: String,
    diff: Vec<DiffLine>,
}

fn read_shared_table() -> Result<SharedDiffTable, serde_json::Error> {
    serde_json::from_str(SHARED_DIFF_TABLE)
}

fn join_lines(lines: &[String]) -> String {
    let mut document = String::new();
    for line in lines {
        document.push_str(line);
        document.push('\n');
    }
    document
}

fn keep_side(diff: &[DiffLine], is_previous_side: bool) -> Vec<String> {
    let mut kept = Vec::new();
    for line in diff {
        match line {
            DiffLine::Unchanged(text) => kept.push(text.clone()),
            DiffLine::Removed(text) if is_previous_side => {
                kept.push(text.clone());
            }
            DiffLine::Added(text) if !is_previous_side => {
                kept.push(text.clone());
            }
            DiffLine::Removed(_) | DiffLine::Added(_) => {}
        }
    }
    kept
}

fn indented_lines() -> impl Strategy<Value = Vec<String>> {
    let indented_line = (INDENTATION, LINE_TEXT)
        .prop_map(|(indentation, text)| format!("{indentation}{text}"));
    vec(indented_line, 0..LARGEST_LINE_COUNT)
}

#[test]
fn test_diff_lines_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_table()?.cases {
        let diff = diff_lines(&case.previous, &case.current);

        assert_eq!(diff, case.diff, "case {}", case.name);
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_diff_lines_property_indentation_change_keeps_both_lines(
        text in LINE_TEXT,
        previous_indentation in INDENTATION,
        current_indentation in INDENTATION,
    ) {
        prop_assume!(previous_indentation != current_indentation);
        let previous_line = format!("{previous_indentation}{text}");
        let current_line = format!("{current_indentation}{text}");

        let diff = diff_lines(
            &join_lines(std::slice::from_ref(&previous_line)),
            &join_lines(std::slice::from_ref(&current_line)),
        );

        prop_assert_eq!(
            diff,
            vec![DiffLine::Removed(previous_line), DiffLine::Added(current_line)]
        );
    }

    #[test]
    fn test_diff_lines_property_sides_rebuild_both_documents(
        previous_lines in indented_lines(),
        current_lines in indented_lines(),
    ) {
        let diff = diff_lines(
            &join_lines(&previous_lines),
            &join_lines(&current_lines),
        );

        prop_assert_eq!(keep_side(&diff, true), previous_lines);
        prop_assert_eq!(keep_side(&diff, false), current_lines);
    }
}

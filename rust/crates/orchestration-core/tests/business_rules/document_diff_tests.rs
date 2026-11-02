use orchestration_core::document_diff::{DiffLine, diff_lines};
use proptest::collection::vec;
use proptest::prelude::*;

const MAXIMUM_LINES: usize = 12;

fn small_alphabet_document() -> impl Strategy<Value = String> {
    vec("[abc]", 0..MAXIMUM_LINES).prop_map(|lines| lines.join("\n"))
}

fn rebuild_previous_lines(diff: &[DiffLine]) -> Vec<String> {
    let mut lines = Vec::new();
    for line in diff {
        match line {
            DiffLine::Unchanged(text) | DiffLine::Removed(text) => {
                lines.push(text.clone());
            }
            DiffLine::Added(_) => {}
        }
    }
    lines
}

fn rebuild_current_lines(diff: &[DiffLine]) -> Vec<String> {
    let mut lines = Vec::new();
    for line in diff {
        match line {
            DiffLine::Unchanged(text) | DiffLine::Added(text) => {
                lines.push(text.clone());
            }
            DiffLine::Removed(_) => {}
        }
    }
    lines
}

fn count_unchanged_lines(diff: &[DiffLine]) -> usize {
    diff.iter()
        .filter(|line| matches!(line, DiffLine::Unchanged(_)))
        .count()
}

fn split_lines(document: &str) -> Vec<String> {
    document.lines().map(str::to_owned).collect()
}

#[test]
fn test_diff_lines_shows_changed_time_limit_like_the_design() {
    let previous = "name: train-ranker\n  - name: train\n    timeout: 2h\n";
    let current = "name: train-ranker\n  - name: train\n    timeout: 6h\n    \
        egress: [huggingface.co]\n";

    let diff = diff_lines(previous, current);

    let expected = vec![
        DiffLine::Unchanged("name: train-ranker".to_owned()),
        DiffLine::Unchanged("  - name: train".to_owned()),
        DiffLine::Removed("    timeout: 2h".to_owned()),
        DiffLine::Added("    timeout: 6h".to_owned()),
        DiffLine::Added("    egress: [huggingface.co]".to_owned()),
    ];
    assert_eq!(diff, expected);
}

proptest! {
    #[test]
    fn test_diff_lines_property_rebuilds_both_documents(
        previous in small_alphabet_document(),
        current in small_alphabet_document(),
    ) {
        let diff = diff_lines(&previous, &current);

        prop_assert_eq!(rebuild_previous_lines(&diff), split_lines(&previous));
        prop_assert_eq!(rebuild_current_lines(&diff), split_lines(&current));
    }

    #[test]
    fn test_diff_lines_property_identical_documents_are_unchanged(
        document in small_alphabet_document(),
    ) {
        let diff = diff_lines(&document, &document);

        let expected: Vec<DiffLine> = split_lines(&document)
            .into_iter()
            .map(DiffLine::Unchanged)
            .collect();
        prop_assert_eq!(diff, expected);
    }

    #[test]
    fn test_diff_lines_property_keeps_as_many_lines_in_either_direction(
        previous in small_alphabet_document(),
        current in small_alphabet_document(),
    ) {
        let forward = diff_lines(&previous, &current);
        let backward = diff_lines(&current, &previous);

        prop_assert_eq!(
            count_unchanged_lines(&forward),
            count_unchanged_lines(&backward)
        );
    }

    #[test]
    fn test_diff_lines_property_keeps_a_shared_suffix_unchanged(
        previous in small_alphabet_document(),
        current in small_alphabet_document(),
        shared in small_alphabet_document(),
    ) {
        let base_diff = diff_lines(&previous, &current);
        let previous_with_suffix = format!("{previous}\n{shared}");
        let current_with_suffix = format!("{current}\n{shared}");

        let extended_diff =
            diff_lines(&previous_with_suffix, &current_with_suffix);

        let shared_line_count = split_lines(&shared).len();
        prop_assert!(
            count_unchanged_lines(&extended_diff)
                >= count_unchanged_lines(&base_diff) + shared_line_count
        );
    }

    #[test]
    fn test_diff_lines_property_lists_removed_before_added_in_each_change(
        previous in small_alphabet_document(),
        current in small_alphabet_document(),
    ) {
        let diff = diff_lines(&previous, &current);

        let mut has_seen_added_in_change = false;
        for line in &diff {
            match line {
                DiffLine::Unchanged(_) => has_seen_added_in_change = false,
                DiffLine::Added(_) => has_seen_added_in_change = true,
                DiffLine::Removed(_) => {
                    prop_assert!(!has_seen_added_in_change);
                }
            }
        }
    }

    #[test]
    fn test_diff_lines_fuzz_arbitrary_text_rebuilds_both_documents(
        previous in any::<String>(),
        current in any::<String>(),
    ) {
        let diff = diff_lines(&previous, &current);

        prop_assert_eq!(rebuild_previous_lines(&diff), split_lines(&previous));
        prop_assert_eq!(rebuild_current_lines(&diff), split_lines(&current));
    }
}

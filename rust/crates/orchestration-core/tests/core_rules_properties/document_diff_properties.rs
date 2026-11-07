use orchestration_core::document_diff::{DiffLine, diff_lines};
use proptest::collection::vec;
use proptest::prelude::*;

const MAXIMUM_LINES: usize = 7;

fn small_document() -> impl Strategy<Value = Vec<String>> {
    vec("[ab]{0,2}", 0..MAXIMUM_LINES)
}

fn count_unchanged(diff: &[DiffLine]) -> usize {
    let mut unchanged_count = 0;
    for line in diff {
        if matches!(line, DiffLine::Unchanged(_)) {
            unchanged_count += 1;
        }
    }
    unchanged_count
}

fn count_reference_common_lines(
    previous: &[String],
    current: &[String],
) -> usize {
    let (Some(previous_first), Some(current_first)) =
        (previous.first(), current.first())
    else {
        return 0;
    };
    let previous_rest = &previous[1..];
    let current_rest = &current[1..];
    if previous_first == current_first {
        return 1 + count_reference_common_lines(previous_rest, current_rest);
    }
    let without_previous =
        count_reference_common_lines(previous_rest, current);
    let without_current = count_reference_common_lines(previous, current_rest);
    without_previous.max(without_current)
}

fn join_document(lines: &[String]) -> String {
    let mut document = String::new();
    for line in lines {
        document.push_str(line);
        document.push('\n');
    }
    document
}

proptest! {
    #[test]
    fn test_measure_common_suffixes_property_keeps_a_longest_common_part(
        previous in small_document(),
        current in small_document(),
    ) {
        let diff = diff_lines(
            &join_document(&previous),
            &join_document(&current),
        );

        let expected = count_reference_common_lines(&previous, &current);

        prop_assert_eq!(count_unchanged(&diff), expected);
    }

    #[test]
    fn test_measure_common_suffixes_property_a_shared_last_line_adds_one(
        previous in small_document(),
        current in small_document(),
        shared_line in "[abc]{0,2}",
    ) {
        let mut longer_previous = previous.clone();
        longer_previous.push(shared_line.clone());
        let mut longer_current = current.clone();
        longer_current.push(shared_line);

        let diff = diff_lines(
            &join_document(&previous),
            &join_document(&current),
        );
        let longer_diff = diff_lines(
            &join_document(&longer_previous),
            &join_document(&longer_current),
        );

        prop_assert_eq!(
            count_unchanged(&longer_diff),
            count_unchanged(&diff) + 1
        );
    }

    #[test]
    fn test_measure_common_suffixes_property_changes_fill_the_rest(
        previous in small_document(),
        current in small_document(),
    ) {
        let diff = diff_lines(
            &join_document(&previous),
            &join_document(&current),
        );
        let unchanged_count = count_unchanged(&diff);

        let removed_count = diff
            .iter()
            .filter(|line| matches!(line, DiffLine::Removed(_)))
            .count();
        let added_count = diff
            .iter()
            .filter(|line| matches!(line, DiffLine::Added(_)))
            .count();

        prop_assert!(unchanged_count <= previous.len().min(current.len()));
        prop_assert_eq!(removed_count, previous.len() - unchanged_count);
        prop_assert_eq!(added_count, current.len() - unchanged_count);
    }

    #[test]
    fn test_diff_line_serde_property_round_trips_with_snake_case_tags(
        previous in small_document(),
        current in small_document(),
    ) {
        let diff = diff_lines(
            &join_document(&previous),
            &join_document(&current),
        );

        let encoded = serde_json::to_value(&diff)
            .map_err(|error| TestCaseError::fail(error.to_string()))?;
        let decoded: Vec<DiffLine> = serde_json::from_value(encoded.clone())
            .map_err(|error| TestCaseError::fail(error.to_string()))?;

        prop_assert_eq!(decoded, diff);
        let encoded_text = encoded.to_string();
        prop_assert!(!encoded_text.contains("Unchanged"));
        prop_assert!(!encoded_text.contains("Added"));
        prop_assert!(!encoded_text.contains("Removed"));
    }
}

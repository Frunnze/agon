use orchestration_core::protected_files::{
    ProtectedFiles, validate_protected_files,
};
use proptest::prelude::*;
use proptest::sample::Index;
use serde::Deserialize;

const SHARED_PATTERN_CASES: &str =
    include_str!("../fixtures/protected_pattern_cases.json");

#[derive(Debug, Deserialize)]
struct SharedPatternCase {
    description: String,
    patterns: Vec<String>,
    problem: Option<String>,
}

fn read_shared_cases() -> Result<Vec<SharedPatternCase>, serde_json::Error> {
    serde_json::from_str(SHARED_PATTERN_CASES)
}

fn describe_problem(patterns: &[String]) -> Option<String> {
    let protected = ProtectedFiles {
        patterns: patterns.to_vec(),
    };
    validate_protected_files(&protected)
        .err()
        .map(|problem| problem.to_string())
}

fn flip_ascii_case(pattern: &str) -> String {
    pattern
        .chars()
        .map(|character| {
            if character.is_ascii_lowercase() {
                character.to_ascii_uppercase()
            } else {
                character.to_ascii_lowercase()
            }
        })
        .collect()
}

#[test]
fn test_validate_protected_files_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let problem = describe_problem(&case.patterns);

        assert_eq!(problem, case.problem, "{}", case.description);
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_validate_protected_files_property_ascii_case_never_matters(
        case_position in any::<Index>(),
    ) {
        let cases = read_shared_cases()?;
        let case = &cases[case_position.index(cases.len())];
        let flipped: Vec<String> = case
            .patterns
            .iter()
            .map(|pattern| flip_ascii_case(pattern))
            .collect();

        let is_valid = describe_problem(&flipped).is_none();

        prop_assert_eq!(is_valid, case.problem.is_none());
    }
}

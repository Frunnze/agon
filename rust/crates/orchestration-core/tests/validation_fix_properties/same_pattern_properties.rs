use orchestration_core::protected_files::{
    ProtectedPatternProblem, validate_protected_files,
};
use orchestration_core::protected_paths::is_protected_path;
use proptest::prelude::*;

use crate::pattern_spelling_support::{
    HOME, PatternShape, example_path, letter_case_spelling, only_patterns,
    pattern_place, pattern_segments, pattern_shape, slash_spelling,
    spell_pattern,
};

const NON_ASCII_LETTER_PAIRS: [(char, char); 4] =
    [('é', 'É'), ('ü', 'Ü'), ('ж', 'Ж'), ('ω', 'Ω')];

fn is_refused_as_duplicate(patterns: &[String]) -> bool {
    let verdict = validate_protected_files(&only_patterns(patterns));
    matches!(verdict, Err(ProtectedPatternProblem::Duplicate { .. }))
}

proptest! {
    #[test]
    fn test_is_same_protected_pattern_property_ignores_slashes_and_dots(
        shape in pattern_shape(),
        first_spelling in slash_spelling(),
        second_spelling in slash_spelling(),
    ) {
        let patterns = vec![
            spell_pattern(&shape, &first_spelling),
            spell_pattern(&shape, &second_spelling),
        ];

        prop_assert!(is_refused_as_duplicate(&patterns), "{:?}", patterns);
    }

    #[test]
    fn test_is_same_protected_pattern_property_ignores_ascii_case(
        shape in pattern_shape(),
        first_spelling in letter_case_spelling(),
        second_spelling in letter_case_spelling(),
    ) {
        let first_pattern = spell_pattern(&shape, &first_spelling);
        let second_pattern = spell_pattern(&shape, &second_spelling);
        let patterns = vec![first_pattern.clone(), second_pattern.clone()];
        let shouted_path = example_path(&shape).to_ascii_uppercase();
        let shouted_home = HOME.to_ascii_uppercase();

        prop_assert!(is_refused_as_duplicate(&patterns), "{:?}", patterns);
        for pattern in [first_pattern, second_pattern] {
            let only_one = only_patterns(&[pattern]);
            prop_assert!(is_protected_path(&only_one, &shouted_path, HOME));
            let protects_under_shouted_home =
                is_protected_path(&only_one, &shouted_path, &shouted_home);
            prop_assert!(protects_under_shouted_home);
        }
    }

    #[test]
    fn test_is_same_protected_pattern_property_tells_places_apart(
        first_place in pattern_place(),
        second_place in pattern_place(),
        segments in pattern_segments(),
        first_spelling in slash_spelling(),
        second_spelling in slash_spelling(),
    ) {
        prop_assume!(first_place != second_place);
        let first_shape = PatternShape {
            place: first_place,
            segments: segments.clone(),
        };
        let second_shape = PatternShape {
            place: second_place,
            segments,
        };
        let patterns = vec![
            spell_pattern(&first_shape, &first_spelling),
            spell_pattern(&second_shape, &second_spelling),
        ];

        let verdict = validate_protected_files(&only_patterns(&patterns));

        prop_assert_eq!(verdict, Ok(()));
    }

    #[test]
    fn test_is_same_protected_pattern_property_keeps_non_ascii_case_apart(
        name_start in "[a-z]{0,4}",
        pair_position in 0..NON_ASCII_LETTER_PAIRS.len(),
    ) {
        let (small_letter, capital_letter) =
            NON_ASCII_LETTER_PAIRS[pair_position];
        let small_pattern = format!("~/.{name_start}{small_letter}");
        let capital_pattern = format!("~/.{name_start}{capital_letter}");
        let patterns = vec![small_pattern.clone(), capital_pattern.clone()];
        let small_path = format!("{HOME}/.{name_start}{small_letter}");
        let capital_only = only_patterns(&[capital_pattern]);
        let small_only = only_patterns(&[small_pattern]);

        let verdict = validate_protected_files(&only_patterns(&patterns));

        prop_assert_eq!(verdict, Ok(()));
        prop_assert!(is_protected_path(&small_only, &small_path, HOME));
        prop_assert!(!is_protected_path(&capital_only, &small_path, HOME));
    }
}

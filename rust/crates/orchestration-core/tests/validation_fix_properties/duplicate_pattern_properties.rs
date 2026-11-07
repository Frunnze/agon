use orchestration_core::protected_files::{
    ProtectedPatternProblem, validate_protected_files,
};
use orchestration_core::protected_paths::is_protected_path;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::Index;

use crate::pattern_spelling_support::{
    HOME, PatternShape, Spelling, example_path, only_patterns, pattern_shape,
    spell_pattern, spelling,
};

const MOST_SHAPES: usize = 3;
const MOST_LISTED_PATTERNS: usize = 8;

fn listed_shapes() -> impl Strategy<Value = Vec<(Index, Spelling)>> {
    vec((any::<Index>(), spelling()), 1..=MOST_LISTED_PATTERNS)
}

fn expect_first_repeat(
    shapes: &[&PatternShape],
    patterns: &[String],
) -> Result<(), ProtectedPatternProblem> {
    for (position, shape) in shapes.iter().enumerate() {
        let earlier_shapes = &shapes[..position];
        let earlier_position = earlier_shapes
            .iter()
            .position(|earlier_shape| earlier_shape == shape);
        if let Some(earlier_position) = earlier_position {
            return Err(ProtectedPatternProblem::Duplicate {
                pattern: patterns[position].clone(),
                earlier_pattern: patterns[earlier_position].clone(),
            });
        }
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_validate_protected_files_property_refuses_a_second_spelling(
        shape in pattern_shape(),
        first_spelling in spelling(),
        second_spelling in spelling(),
    ) {
        let first_pattern = spell_pattern(&shape, &first_spelling);
        let second_pattern = spell_pattern(&shape, &second_spelling);
        let patterns = vec![first_pattern.clone(), second_pattern.clone()];

        let verdict = validate_protected_files(&only_patterns(&patterns));

        prop_assert_eq!(
            verdict,
            Err(ProtectedPatternProblem::Duplicate {
                pattern: second_pattern,
                earlier_pattern: first_pattern,
            })
        );
    }

    #[test]
    fn test_validate_protected_files_property_agrees_with_a_repeat_model(
        shape_pool in vec(pattern_shape(), 1..=MOST_SHAPES),
        listed in listed_shapes(),
    ) {
        let mut shapes = Vec::new();
        let mut patterns = Vec::new();
        for (shape_choice, chosen_spelling) in &listed {
            let shape = &shape_pool[shape_choice.index(shape_pool.len())];
            shapes.push(shape);
            patterns.push(spell_pattern(shape, chosen_spelling));
        }

        let verdict = validate_protected_files(&only_patterns(&patterns));

        prop_assert_eq!(verdict, expect_first_repeat(&shapes, &patterns));
    }

    #[test]
    fn test_validate_protected_files_property_refused_pairs_match_alike(
        first_shape in pattern_shape(),
        second_shape in pattern_shape(),
        first_spelling in spelling(),
        second_spelling in spelling(),
        is_same_shape in any::<bool>(),
    ) {
        let second_shape = if is_same_shape {
            first_shape.clone()
        } else {
            second_shape
        };
        let first_pattern = spell_pattern(&first_shape, &first_spelling);
        let second_pattern = spell_pattern(&second_shape, &second_spelling);
        let patterns = vec![first_pattern.clone(), second_pattern.clone()];
        let verdict = validate_protected_files(&only_patterns(&patterns));
        if verdict.is_ok() {
            return Ok(());
        }

        let first_only = only_patterns(&[first_pattern]);
        let second_only = only_patterns(&[second_pattern]);
        let checked_paths = [
            example_path(&first_shape),
            example_path(&second_shape),
            format!("{}/inside", example_path(&first_shape)),
            HOME.to_owned(),
        ];
        for path in &checked_paths {
            prop_assert_eq!(
                is_protected_path(&first_only, path, HOME),
                is_protected_path(&second_only, path, HOME),
                "{}",
                path
            );
        }
    }

    #[test]
    fn test_validate_protected_files_property_keeps_one_spelling_each(
        shapes in vec(pattern_shape(), 1..=MOST_LISTED_PATTERNS),
        spellings in vec(spelling(), MOST_LISTED_PATTERNS),
    ) {
        let mut distinct_shapes: Vec<PatternShape> = Vec::new();
        for shape in shapes {
            if !distinct_shapes.contains(&shape) {
                distinct_shapes.push(shape);
            }
        }
        let shape_spellings = distinct_shapes.iter().zip(&spellings);
        let mut patterns = Vec::new();
        for (shape, chosen_spelling) in shape_spellings {
            patterns.push(spell_pattern(shape, chosen_spelling));
        }

        let verdict = validate_protected_files(&only_patterns(&patterns));

        prop_assert_eq!(verdict, Ok(()));
    }
}

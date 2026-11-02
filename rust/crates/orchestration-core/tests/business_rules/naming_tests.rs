use std::ops::RangeInclusive;

use orchestration_core::naming::{
    MAXIMUM_NAME_LENGTH, NameProblem, validate_name,
};
use proptest::collection::vec;
use proptest::prelude::*;

const LONGEST_GENERATED_NAME: usize = 2 * MAXIMUM_NAME_LENGTH;

fn name_with_lengths(
    lengths: RangeInclusive<usize>,
) -> impl Strategy<Value = String> {
    vec("[a-z0-9-]", lengths).prop_map(|characters| characters.concat())
}

fn is_allowed_character(character: char) -> bool {
    character.is_ascii_lowercase()
        || character.is_ascii_digit()
        || character == '-'
}

proptest! {
    #[test]
    fn test_validate_name_property_accepts_allowed_names(
        name in name_with_lengths(1..=MAXIMUM_NAME_LENGTH),
    ) {
        prop_assert_eq!(validate_name(&name), Ok(()));
    }

    #[test]
    fn test_validate_name_property_rejects_names_over_the_limit(
        name in name_with_lengths(
            MAXIMUM_NAME_LENGTH + 1..=LONGEST_GENERATED_NAME,
        ),
    ) {
        let length = name.chars().count();

        prop_assert_eq!(
            validate_name(&name),
            Err(NameProblem::TooLong { length })
        );
    }

    #[test]
    fn test_validate_name_property_names_the_first_disallowed_character(
        prefix in "[a-z0-9-]{0,10}",
        character in any::<char>().prop_filter(
            "disallowed character",
            |character| !is_allowed_character(*character),
        ),
        suffix in "[a-z0-9-]{0,10}",
    ) {
        let name = format!("{prefix}{character}{suffix}");

        prop_assert_eq!(
            validate_name(&name),
            Err(NameProblem::InvalidCharacter { character })
        );
    }

    #[test]
    fn test_validate_name_fuzz_arbitrary_text_matches_the_naming_rule(
        name in any::<String>(),
    ) {
        let length = name.chars().count();
        let has_allowed_length = (1..=MAXIMUM_NAME_LENGTH).contains(&length);
        let follows_rule = has_allowed_length
            && name.chars().all(is_allowed_character);

        let verdict = validate_name(&name);

        prop_assert_eq!(verdict.is_ok(), follows_rule);
    }
}

#[test]
fn test_validate_name_rejects_an_empty_name() {
    assert_eq!(validate_name(""), Err(NameProblem::Empty));
}

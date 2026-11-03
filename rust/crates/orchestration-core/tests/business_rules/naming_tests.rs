use std::ops::RangeInclusive;

use orchestration_core::naming::{
    FALLBACK_PROJECT_NAME, MAXIMUM_NAME_LENGTH, NameProblem,
    convert_to_project_name, validate_name,
};
use proptest::collection::vec;
use proptest::prelude::*;

const LONGEST_GENERATED_NAME: usize = 2 * MAXIMUM_NAME_LENGTH;
const NAME_EXAMPLES: [(&str, &str); 5] = [
    ("Billing UI", "billing-ui"),
    ("site_2", "site-2"),
    (".dotfiles", "dotfiles"),
    ("My  App (old)", "my-app-old"),
    ("___", FALLBACK_PROJECT_NAME),
];

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

proptest! {
    #[test]
    fn test_convert_to_project_name_property_always_gives_a_valid_name(
        folder_or_repository_name in any::<String>(),
    ) {
        let project_name = convert_to_project_name(&folder_or_repository_name);

        prop_assert_eq!(validate_name(&project_name), Ok(()));
    }

    #[test]
    fn test_convert_to_project_name_property_is_idempotent(
        folder_or_repository_name in any::<String>(),
    ) {
        let project_name = convert_to_project_name(&folder_or_repository_name);

        let converted_again = convert_to_project_name(&project_name);

        prop_assert_eq!(converted_again, project_name);
    }

    #[test]
    fn test_convert_to_project_name_property_keeps_letters_and_digits(
        folder_or_repository_name in "[a-z0-9]{1,40}",
    ) {
        let project_name = convert_to_project_name(&folder_or_repository_name);

        prop_assert_eq!(project_name, folder_or_repository_name);
    }
}

#[test]
fn test_convert_to_project_name_turns_other_characters_into_dashes() {
    for (folder_or_repository_name, expected) in NAME_EXAMPLES {
        assert_eq!(
            convert_to_project_name(folder_or_repository_name),
            expected
        );
    }
}

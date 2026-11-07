use orchestration_core::naming::{
    NameProblem, convert_to_project_name, validate_name,
};
use proptest::prelude::*;

fn name_character() -> impl Strategy<Value = char> {
    prop_oneof![
        proptest::char::range('a', 'z'),
        proptest::char::range('0', '9'),
        Just('-'),
    ]
}

fn lookalike_character() -> impl Strategy<Value = char> {
    prop_oneof![
        proptest::char::range('A', 'Z'),
        Just('_'),
        Just(' '),
        Just('.'),
        Just('\u{e9}'),
        Just('\u{663}'),
        Just('\u{ff41}'),
        Just('\u{2010}'),
        Just('\u{212a}'),
    ]
}

proptest! {
    #[test]
    fn test_is_name_character_property_accepts_letters_digits_and_dashes(
        character in name_character(),
    ) {
        prop_assert_eq!(validate_name(&character.to_string()), Ok(()));
    }

    #[test]
    fn test_is_name_character_property_refuses_lookalike_characters(
        prefix in "[a-z0-9-]{0,5}",
        character in lookalike_character(),
        suffix in "[a-z0-9-]{0,5}",
    ) {
        let name = format!("{prefix}{character}{suffix}");

        prop_assert_eq!(
            validate_name(&name),
            Err(NameProblem::InvalidCharacter { character })
        );
    }

    #[test]
    fn test_is_name_character_property_project_names_keep_only_them(
        folder_name in ".{0,20}",
    ) {
        let project_name = convert_to_project_name(&folder_name);

        for character in project_name.chars() {
            prop_assert_eq!(validate_name(&character.to_string()), Ok(()));
        }
    }
}

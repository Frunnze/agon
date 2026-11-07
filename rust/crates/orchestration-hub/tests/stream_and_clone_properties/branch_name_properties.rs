use std::io;
use std::process::Command;

use orchestration_hub::branch_names::is_valid_branch_name;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::Index;

const GIT_SPECIAL_CHARACTERS: [char; 8] =
    [' ', '~', '^', ':', '?', '*', '[', '\\'];
const GIT_CHECK_CASES: u32 = 48;
const NAME_PARTS: [&str; 14] = [
    "HEAD", "head", "main", "a", ".a", "a.lock", "a.locked", "a.", "", "@",
    "-a", "a..b", "x@{y", "é中",
];

fn any_plain_component() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9é中😀_+=,#!%&()-][a-zA-Z0-9é中😀_.+=,#!%&()-]{0,10}"
        .prop_filter("a plain component", |component| {
            !component.ends_with('.')
                && !component.contains(".lock")
                && !component.contains("..")
                && !component.starts_with('-')
        })
}

fn any_plain_name() -> impl Strategy<Value = Vec<String>> {
    vec(any_plain_component(), 1..4)
}

fn any_ascii_control() -> impl Strategy<Value = char> {
    prop_oneof![(0_u8..0x20).prop_map(char::from), Just(char::from(0x7f_u8)),]
}

fn insert_character(text: &str, position: Index, character: char) -> String {
    let mut characters: Vec<char> = text.chars().collect();
    let slot = position.index(characters.len() + 1);
    characters.insert(slot, character);
    characters.into_iter().collect()
}

fn git_accepts_branch(name: &str) -> Result<bool, io::Error> {
    let outside_any_repository = tempfile::tempdir()?;
    let output = Command::new("git")
        .args(["check-ref-format", "--branch", name])
        .current_dir(outside_any_repository.path())
        .output()?;
    Ok(output.status.success())
}

fn ask_git(name: &str) -> Result<bool, TestCaseError> {
    git_accepts_branch(name)
        .map_err(|problem| TestCaseError::fail(problem.to_string()))
}

proptest! {
    #[test]
    fn test_is_forbidden_character_property_ascii_controls_are_refused(
        components in any_plain_name(),
        control in any_ascii_control(),
        position in any::<Index>(),
    ) {
        let name = components.join("/");
        let with_control = insert_character(&name, position, control);

        prop_assert!(is_valid_branch_name(&name));
        prop_assert!(!is_valid_branch_name(&with_control));
    }

    #[test]
    fn test_is_forbidden_character_property_git_specials_refused_anywhere(
        components in any_plain_name(),
        special in proptest::sample::select(GIT_SPECIAL_CHARACTERS.to_vec()),
        position in any::<Index>(),
    ) {
        let name = components.join("/");
        let with_special = insert_character(&name, position, special);

        prop_assert!(!is_valid_branch_name(&with_special));
    }

    #[test]
    fn test_is_valid_component_property_hidden_components_are_refused(
        components in any_plain_name(),
        hidden_position in any::<Index>(),
    ) {
        let mut hidden_components = components.clone();
        let slot = hidden_position.index(hidden_components.len());
        hidden_components[slot] = format!(".{}", hidden_components[slot]);

        prop_assert!(is_valid_branch_name(&components.join("/")));
        prop_assert!(!is_valid_branch_name(&hidden_components.join("/")));
    }

    #[test]
    fn test_is_valid_component_property_lock_suffix_refused_per_component(
        components in any_plain_name(),
        locked_position in any::<Index>(),
    ) {
        let slot = locked_position.index(components.len());
        let mut locked_components = components.clone();
        locked_components[slot] = format!("{}.lock", components[slot]);
        let mut inner_lock_components = components.clone();
        inner_lock_components[slot] = format!("{}.lock.x", components[slot]);

        prop_assert!(!is_valid_branch_name(&locked_components.join("/")));
        prop_assert!(is_valid_branch_name(&inner_lock_components.join("/")));
    }

    #[test]
    fn test_is_valid_component_property_empty_components_are_refused(
        components in any_plain_name(),
        empty_position in any::<Index>(),
    ) {
        let mut with_empty = components.clone();
        let slot = empty_position.index(with_empty.len() + 1);
        with_empty.insert(slot, String::new());

        prop_assert!(!is_valid_branch_name(&with_empty.join("/")));
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CHECK_CASES))]

    #[test]
    fn test_is_forbidden_character_property_agrees_with_git_per_character(
        code in 1_u32..0x80,
        prefix in "[a-z]{1,3}",
        suffix in "[a-z]{1,3}",
    ) {
        let character = char::from_u32(code).unwrap_or_default();
        let name = format!("{prefix}{character}{suffix}");

        prop_assert_eq!(is_valid_branch_name(&name), ask_git(&name)?);
    }

    #[test]
    fn test_is_valid_branch_name_property_agrees_with_git_on_parts(
        parts in vec(proptest::sample::select(NAME_PARTS.to_vec()), 1..4),
    ) {
        let name = parts.join("/");

        prop_assert_eq!(is_valid_branch_name(&name), ask_git(&name)?);
    }
}

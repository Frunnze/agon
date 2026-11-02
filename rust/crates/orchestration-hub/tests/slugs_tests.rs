use std::process::Command;

use orchestration_hub::branch_names::is_valid_branch_name;
use orchestration_hub::slugs::{MAXIMUM_SLUG_LENGTH, slugify};
use proptest::prelude::*;

const FORBIDDEN_BRANCH_CHARACTERS: [char; 10] =
    [' ', '~', '^', ':', '?', '*', '[', '\\', '\n', '\x7f'];

const BADLY_SHAPED_BRANCHES: [&str; 11] = [
    "",
    "-task",
    "task/",
    "/task",
    "task//one",
    "task.",
    "task/.hidden",
    "task..one",
    "task@{one",
    "task.lock",
    "task.lock/one",
];

fn any_hostile_text() -> impl Strategy<Value = String> {
    prop_oneof![
        any::<String>(),
        Just("../../etc".to_string()),
        "[-./ _A-Z]{0,30}",
        "[a-zA-Z0-9 ]{60,200}",
    ]
}

fn any_forbidden_character() -> impl Strategy<Value = char> {
    proptest::sample::select(FORBIDDEN_BRANCH_CHARACTERS.to_vec())
}

fn is_slug_character(character: char) -> bool {
    character.is_ascii_lowercase()
        || character.is_ascii_digit()
        || character == '-'
}

fn git_accepts_branch(name: &str) -> Result<bool, std::io::Error> {
    let outside_any_repository = tempfile::tempdir()?;
    let status = Command::new("git")
        .args(["check-ref-format", "--branch", name])
        .current_dir(outside_any_repository.path())
        .output()?
        .status;
    Ok(status.success())
}

proptest! {
    #[test]
    fn test_slugify_property_uses_only_lowercase_letters_digits_and_dashes(
        text in any_hostile_text(),
    ) {
        let slug = slugify(&text);

        prop_assert!(slug.chars().all(is_slug_character));
        prop_assert!(!slug.contains("--"));
        prop_assert!(!slug.starts_with('-'));
        prop_assert!(!slug.ends_with('-'));
    }

    #[test]
    fn test_slugify_property_length_is_capped(text in any_hostile_text()) {
        prop_assert!(slugify(&text).len() <= MAXIMUM_SLUG_LENGTH);
    }

    #[test]
    fn test_slugify_property_is_idempotent(text in any_hostile_text()) {
        let slug = slugify(&text);

        prop_assert_eq!(slugify(&slug), slug);
    }

    #[test]
    fn test_slugify_property_ignores_letter_case(text in "[ -~]{0,60}") {
        let shouted = text.to_ascii_uppercase();

        prop_assert_eq!(slugify(&shouted), slugify(&text));
    }

    #[test]
    fn test_slugify_property_joins_the_words_of_plain_titles(
        words in proptest::collection::vec("[a-z0-9]{1,6}", 1..5),
        separator in "[ _./:]{1,3}",
    ) {
        let title = words.join(&separator);

        prop_assert_eq!(slugify(&title), words.join("-"));
    }

    #[test]
    fn test_is_valid_branch_name_property_accepts_task_branches(
        text in any_hostile_text(),
        run_number in any::<u32>(),
    ) {
        let slug = slugify(&text);
        prop_assume!(!slug.is_empty());

        let task_branch = format!("task/{slug}");
        let job_run_branch = format!("task/{slug}-run-{run_number}");

        prop_assert!(is_valid_branch_name(&task_branch));
        prop_assert!(is_valid_branch_name(&job_run_branch));
    }

    #[test]
    fn test_is_valid_branch_name_property_rejects_forbidden_characters(
        prefix in "[a-z]{0,6}",
        forbidden in any_forbidden_character(),
        suffix in "[a-z]{0,6}",
    ) {
        let name = format!("{prefix}{forbidden}{suffix}");

        prop_assert!(!is_valid_branch_name(&name));
    }

    #[test]
    fn test_is_valid_branch_name_property_rejects_bad_shapes(
        name in proptest::sample::select(BADLY_SHAPED_BRANCHES.to_vec()),
    ) {
        prop_assert!(!is_valid_branch_name(name));
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(64))]

    #[test]
    fn test_is_valid_branch_name_property_agrees_with_git(
        name in "[a-z./@{}~^:?*\\[\\\\ -]{1,8}",
    ) {
        let accepted_by_git = git_accepts_branch(&name)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(is_valid_branch_name(&name), accepted_by_git);
    }
}

use orchestration_hub::command_label::label_shell_command;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::command_label_support::{
    RUN_THE_TESTS, UNNAMED_COMMAND_LABEL, any_named_command, any_separator,
    any_skipped_prefix, any_unknown_program, any_words, join_command,
};

fn any_assignment() -> impl Strategy<Value = String> {
    ("[A-Za-z_][A-Za-z0-9_]{0,6}", "[a-z0-9/._-]{0,6}")
        .prop_map(|(name, value)| format!("{name}={value}"))
}

fn any_flag() -> impl Strategy<Value = String> {
    prop_oneof![
        "-[a-zA-Z]{1,3}",
        "--[a-z][a-z-]{1,8}",
        "--[a-z]{1,8}=[a-z0-9]{0,6}",
    ]
}

proptest! {
    #[test]
    fn test_label_shell_command_property_only_the_first_line_counts(
        (command, label) in any_named_command(),
        later_lines in vec("\\PC{0,30}", 1..3),
    ) {
        let script = format!("{command}\n{}", later_lines.join("\n"));

        prop_assert_eq!(label_shell_command(&script), label);
    }

    #[test]
    fn test_label_shell_command_property_flags_never_rename_a_command(
        (command, label) in any_named_command(),
        flags in vec(any_flag(), 0..4),
    ) {
        let flagged = join_command(&command, &flags);

        prop_assert_eq!(label_shell_command(&flagged), label);
    }

    #[test]
    fn test_split_shell_words_property_unbalanced_quotes_keep_the_label(
        (command, label) in any_named_command(),
        quote in prop_oneof![Just('"'), Just('\'')],
        message in "[a-z ]{0,12}",
    ) {
        let unbalanced = format!("{command} {quote}{message}");

        prop_assert_eq!(label_shell_command(&unbalanced), label);
    }

    #[test]
    fn test_split_shell_words_property_quoted_words_stay_whole(
        runner in prop_oneof![Just("npx"), Just("bunx")],
        words in vec("[a-z0-9]{1,5}", 1..4),
        quote in prop_oneof![Just('"'), Just('\'')],
    ) {
        let package = words.join(" ");
        let script = format!("{runner} {quote}{package}{quote} --yes");

        prop_assert_eq!(
            label_shell_command(&script),
            format!("Run {package}"),
        );
    }

    #[test]
    fn test_split_shell_words_property_extra_spaces_never_matter(
        (command, label) in any_named_command(),
        arguments in any_words(),
        gap in "[ \t]{1,4}",
    ) {
        let words: Vec<&str> = command
            .split(' ')
            .chain(arguments.iter().map(String::as_str))
            .collect();
        let script = format!("{gap}{}{gap}", words.join(&gap));

        prop_assert_eq!(label_shell_command(&script), label);
    }

    #[test]
    fn test_find_main_program_property_skips_folder_changes_and_exports(
        prefixes in vec((any_skipped_prefix(), any_separator()), 0..4),
        (command, label) in any_named_command(),
    ) {
        let mut parts = Vec::new();
        for (prefix, separator) in &prefixes {
            parts.push(format!("{prefix} {separator}"));
        }
        parts.push(command);
        let script = parts.join(" ");

        prop_assert_eq!(label_shell_command(&script), label);
    }

    #[test]
    fn test_find_main_program_property_only_skipped_parts_are_unnamed(
        prefixes in vec((any_skipped_prefix(), any_separator()), 1..4),
    ) {
        let mut parts = Vec::new();
        for (prefix, separator) in &prefixes {
            parts.push(format!("{prefix} {separator}"));
        }
        let script = parts.join(" ");

        prop_assert_eq!(label_shell_command(&script), UNNAMED_COMMAND_LABEL);
    }

    #[test]
    fn test_find_main_program_property_later_programs_never_matter(
        (command, label) in any_named_command(),
        separator in any_separator(),
        later_program in any_unknown_program(),
        later_words in any_words(),
    ) {
        let later_command = join_command(&later_program, &later_words);
        let script = format!("{command} {separator} {later_command}");

        prop_assert_eq!(label_shell_command(&script), label);
    }

    #[test]
    fn test_is_variable_assignment_property_settings_before_are_skipped(
        assignments in vec(any_assignment(), 0..4),
        (command, label) in any_named_command(),
    ) {
        let script = format!("{} {command}", assignments.join(" "));

        prop_assert_eq!(label_shell_command(&script), label);
    }

    #[test]
    fn test_is_variable_assignment_property_digit_names_are_programs(
        name in "[0-9][A-Za-z0-9_]{0,5}",
        value in "[a-z0-9]{0,5}",
    ) {
        let program = format!("{name}={value}");

        let label = label_shell_command(&format!("{program} npm test"));

        prop_assert_eq!(label, format!("Run {program}"));
    }

    #[test]
    fn test_is_variable_assignment_property_empty_names_are_programs(
        value in "[a-z0-9]{0,5}",
    ) {
        let program = format!("={value}");

        let label = label_shell_command(&format!("{program} npm test"));

        prop_assert_eq!(label, format!("Run {program}"));
    }

    #[test]
    fn test_is_identifier_character_property_other_characters_make_programs(
        start in "[A-Za-z_]{1,3}",
        odd_character in "[-.:@+é中]",
        value in "[a-z0-9]{0,4}",
    ) {
        let program = format!("{start}{odd_character}={value}");

        let label = label_shell_command(&format!("{program} npm test"));

        prop_assert_eq!(label, format!("Run {program}"));
    }

    #[test]
    fn test_is_identifier_character_property_letters_digits_underscores(
        name in "[A-Za-z_][A-Za-z0-9_]{0,8}",
    ) {
        let script = format!("{name}=1 npm test");

        prop_assert_eq!(label_shell_command(&script), RUN_THE_TESTS);
    }

    #[test]
    fn test_is_identifier_character_property_case_never_matters(
        name in "[a-z_][a-z0-9_]{0,8}",
    ) {
        let lower = format!("{name}=1 cargo test");
        let upper = format!("{}=1 cargo test", name.to_uppercase());

        prop_assert_eq!(label_shell_command(&lower), RUN_THE_TESTS);
        prop_assert_eq!(label_shell_command(&upper), RUN_THE_TESTS);
    }
}

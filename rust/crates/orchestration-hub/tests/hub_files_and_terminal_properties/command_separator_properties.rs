use orchestration_hub::command_label::label_shell_command;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::select;

use crate::command_label_support::{
    any_named_command, any_separator, any_skipped_prefix, any_unknown_program,
};

const SEPARATOR_CHARACTERS: [char; 3] = ['&', '|', ';'];

proptest! {
    #[test]
    fn test_space_out_separators_property_separators_need_no_spaces(
        prefix in any_skipped_prefix(),
        separator in any_separator(),
        (command, label) in any_named_command(),
    ) {
        let spaced = format!("{prefix} {separator} {command}");
        let joined = format!("{prefix}{separator}{command}");

        prop_assert_eq!(label_shell_command(&spaced), label.clone());
        prop_assert_eq!(label_shell_command(&joined), label);
    }

    #[test]
    fn test_space_out_separators_property_separator_runs_end_one_part(
        prefix in any_skipped_prefix(),
        separators in vec(select(SEPARATOR_CHARACTERS.to_vec()), 1..4),
        (command, label) in any_named_command(),
    ) {
        let separator_run: String = separators.into_iter().collect();
        let script = format!("{prefix}{separator_run}{command}");

        prop_assert_eq!(label_shell_command(&script), label);
    }

    #[test]
    fn test_space_out_separators_property_background_jobs_end_a_part(
        prefix in any_skipped_prefix(),
        (command, label) in any_named_command(),
    ) {
        let background = format!("{prefix} & {command} &");

        prop_assert_eq!(label_shell_command(&background), label);
    }

    #[test]
    fn test_follow_quoting_property_quoted_separators_are_text(
        program in any_unknown_program(),
        separator in any_separator(),
        quote in prop_oneof![Just('"'), Just('\'')],
        words in vec("[a-z]{1,4}", 1..3),
    ) {
        let package = format!("{program}{separator}{}", words.join(separator));
        let script = format!("npx {quote}{package}{quote}");

        prop_assert_eq!(
            label_shell_command(&script),
            format!("Run {package}"),
        );
    }

    #[test]
    fn test_follow_quoting_property_escaped_separators_are_text(
        program in any_unknown_program(),
        separator in select(SEPARATOR_CHARACTERS.to_vec()),
        word in "[a-z]{1,4}",
    ) {
        let script = format!("npx {program}\\{separator}{word}");

        let expected = format!("Run {program}{separator}{word}");
        prop_assert_eq!(label_shell_command(&script), expected);
    }

    #[test]
    fn test_follow_quoting_property_quotes_end_where_the_shell_ends_them(
        word in "[a-z]{1,4}",
        (command, label) in any_named_command(),
    ) {
        let single_quoted = format!("cd '{word}\\'&&{command}");
        let double_quoted = format!("cd \"{word}\\\"\"&&{command}");

        prop_assert_eq!(label_shell_command(&single_quoted), label.clone());
        prop_assert_eq!(label_shell_command(&double_quoted), label);
    }
}

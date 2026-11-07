use orchestration_hub::command_label::label_shell_command;
use proptest::prelude::*;
use proptest::sample::select;

use crate::command_label_support::{
    PACKAGE_MANAGERS, PACKAGE_RUNNERS, PROGRAM_LABELS, RUN_THE_TESTS,
    SUBCOMMAND_LABELS, SUBCOMMAND_PROGRAMS, any_named_command,
    any_unknown_program, any_word, any_words, join_command,
};

const INSTALL_SUBCOMMANDS: [&str; 4] = ["install", "i", "add", "ci"];
const TEST_SUBCOMMANDS: [&str; 3] = ["test", "t", "run test"];
const FLAGS_WITH_VALUES: [(&str, &str); 9] = [
    ("git", "-C"),
    ("git", "-c"),
    ("go", "-C"),
    ("npm", "--prefix"),
    ("pnpm", "-C"),
    ("pnpm", "--dir"),
    ("pnpm", "--filter"),
    ("yarn", "--cwd"),
    ("bun", "--cwd"),
];

fn any_folder_path() -> impl Strategy<Value = String> {
    prop_oneof![Just(String::new()), "(/[a-z0-9._-]{1,8}){1,3}/", "\\./"]
}

fn any_package() -> impl Strategy<Value = String> {
    "[a-z@][a-z0-9@/._-]{0,10}"
}

fn any_subcommand() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("test".to_owned()),
        Just("status".to_owned()),
        Just("install".to_owned()),
        any_word(),
    ]
}

fn any_other_subcommand() -> impl Strategy<Value = String> {
    "[a-z][a-z0-9]{1,8}".prop_filter("the subcommand is unnamed", |word| {
        let is_install = INSTALL_SUBCOMMANDS.contains(&word.as_str());
        let is_test = word == "test" || word == "t" || word == "run";
        !is_install && !is_test
    })
}

proptest! {
    #[test]
    fn test_name_program_property_paths_name_their_last_part(
        folder in any_folder_path(),
        (command, label) in any_named_command(),
    ) {
        let script = format!("{folder}{command}");

        prop_assert_eq!(label_shell_command(&script), label);
    }

    #[test]
    fn test_name_program_property_unknown_paths_show_the_file_name(
        folder in any_folder_path(),
        program in any_unknown_program(),
        arguments in any_words(),
    ) {
        let script = join_command(&format!("{folder}{program}"), &arguments);

        prop_assert_eq!(
            label_shell_command(&script),
            format!("Run {program}"),
        );
    }

    #[test]
    fn test_name_program_property_names_never_hold_a_folder(
        folder in "(/[a-z0-9]{1,8}){1,3}",
        program in "[a-z0-9][a-z0-9._]{0,10}",
    ) {
        let label = label_shell_command(&format!("{folder}/{program}"));

        prop_assert!(!label.contains(&folder), "{}", label);
    }

    #[test]
    fn test_label_program_property_table_programs_ignore_arguments(
        (program, label) in select(PROGRAM_LABELS.to_vec()),
        arguments in any_words(),
    ) {
        let script = join_command(program, &arguments);

        prop_assert_eq!(label_shell_command(&script), label);
    }

    #[test]
    fn test_label_program_property_runners_name_the_package(
        runner in select(PACKAGE_RUNNERS.to_vec()),
        package in any_package(),
        arguments in any_words(),
    ) {
        let script =
            join_command(&format!("{runner} -y {package}"), &arguments);

        prop_assert_eq!(
            label_shell_command(&script),
            format!("Run {package}"),
        );
    }

    #[test]
    fn test_label_program_property_runners_alone_are_named(
        runner in select(PACKAGE_RUNNERS.to_vec()),
        flags in proptest::collection::vec("-[a-z]{1,3}", 0..3),
    ) {
        let script = join_command(runner, &flags);

        prop_assert_eq!(label_shell_command(&script), format!("Run {runner}"));
    }

    #[test]
    fn test_label_package_command_property_install_lists_every_package(
        manager in select(PACKAGE_MANAGERS.to_vec()),
        subcommand in select(INSTALL_SUBCOMMANDS.to_vec()),
        packages in proptest::collection::vec(any_package(), 0..4),
    ) {
        let script =
            join_command(&format!("{manager} {subcommand}"), &packages);

        let expected = if packages.is_empty() {
            format!("Install packages with {manager}")
        } else {
            format!("Install {} with {manager}", packages.join(", "))
        };
        prop_assert_eq!(label_shell_command(&script), expected);
    }

    #[test]
    fn test_label_package_command_property_tests_are_named_alike(
        manager in select(PACKAGE_MANAGERS.to_vec()),
        subcommand in select(TEST_SUBCOMMANDS.to_vec()),
        arguments in any_words(),
    ) {
        let script =
            join_command(&format!("{manager} {subcommand}"), &arguments);

        prop_assert_eq!(label_shell_command(&script), RUN_THE_TESTS);
    }

    #[test]
    fn test_label_package_command_property_other_commands_are_named(
        manager in select(PACKAGE_MANAGERS.to_vec()),
        script_name in any_other_subcommand(),
    ) {
        let run_script = format!("{manager} run {script_name}");
        let other_command = format!("{manager} {script_name}");

        let run_label = label_shell_command(&run_script);
        let other_label = label_shell_command(&other_command);

        prop_assert_eq!(run_label, format!("Run the {script_name} script"));
        prop_assert_eq!(other_label, format!("Run {manager} {script_name}"));
        prop_assert_eq!(
            label_shell_command(manager),
            format!("Run {manager}"),
        );
    }

    #[test]
    fn test_label_subcommand_property_known_pairs_use_the_table(
        (program, subcommand, label) in select(SUBCOMMAND_LABELS.to_vec()),
        arguments in any_words(),
    ) {
        let script =
            join_command(&format!("{program} {subcommand}"), &arguments);

        prop_assert_eq!(label_shell_command(&script), label);
    }

    #[test]
    fn test_label_subcommand_property_unknown_subcommands_are_named(
        program in select(SUBCOMMAND_PROGRAMS.to_vec()),
        subcommand in "[a-z][a-z0-9-]{1,8}",
        arguments in any_words(),
    ) {
        let is_named = SUBCOMMAND_LABELS
            .iter()
            .any(|(known, named, _label)| {
                *known == program && *named == subcommand
            });
        prop_assume!(!is_named);
        let script =
            join_command(&format!("{program} {subcommand}"), &arguments);

        let expected = format!("Run {program} {subcommand}");
        prop_assert_eq!(label_shell_command(&script), expected);
    }

    #[test]
    fn test_label_subcommand_property_programs_alone_are_named(
        program in select(SUBCOMMAND_PROGRAMS.to_vec()),
        flags in proptest::collection::vec("--[a-z]{1,6}", 0..3),
    ) {
        let script = join_command(program, &flags);

        prop_assert_eq!(
            label_shell_command(&script),
            format!("Run {program}"),
        );
    }

    #[test]
    fn test_collect_arguments_property_flag_values_are_not_subcommands(
        (program, flag) in select(FLAGS_WITH_VALUES.to_vec()),
        flag_value in any_word(),
        subcommand in any_subcommand(),
        arguments in any_words(),
    ) {
        let rest = join_command(&subcommand, &arguments);
        let script = format!("{program} {flag} {flag_value} {rest}");
        let plain_script = format!("{program} {rest}");

        let expected = label_shell_command(&plain_script);
        prop_assert_eq!(label_shell_command(&script), expected);
    }

    #[test]
    fn test_collect_arguments_property_joined_flag_values_are_flags(
        (program, flag) in select(FLAGS_WITH_VALUES.to_vec()),
        flag_value in any_word(),
        subcommand in any_subcommand(),
    ) {
        let script = format!("{program} {flag}={flag_value} {subcommand}");
        let plain_script = format!("{program} {subcommand}");

        let expected = label_shell_command(&plain_script);
        prop_assert_eq!(label_shell_command(&script), expected);
    }

    #[test]
    fn test_collect_arguments_property_packages_keep_their_order(
        manager in select(PACKAGE_MANAGERS.to_vec()),
        packages in proptest::collection::vec(any_package(), 1..4),
        flags in proptest::collection::vec("--save-[a-z]{1,4}", 0..3),
    ) {
        let mut words = flags.clone();
        words.extend(packages.iter().cloned());
        let script = join_command(&format!("{manager} add"), &words);

        let expected =
            format!("Install {} with {manager}", packages.join(", "));
        prop_assert_eq!(label_shell_command(&script), expected);
    }
}

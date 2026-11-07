use std::collections::BTreeMap;
use std::path::PathBuf;

use orchestration_core::device::SandboxKind;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::sandbox::{
    SandboxError, wrap_in_sandbox, wrap_in_sandbox_keeping_input_open,
};
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use proptest::collection::btree_map;
use proptest::prelude::*;
use proptest::sample::select;

use crate::hostile_mounts::container_options;
use crate::sandbox_support::{
    any_hosts, any_inner_command, any_mounts, any_settings, wrap_in_container,
};

const ENVIRONMENT_OPTION: &str = "--env";
const ALLOWED_HOSTS_VARIABLE: &str = "ORCHESTRATION_ALLOWED_HOSTS";
const KEEP_INPUT_OPEN_OPTION: &str = "--interactive";
const SECRET_PATTERN: &str = "secret-[a-z0-9]{8,16}";
const NAME_PATTERN: &str = "[A-Za-z_][A-Za-z0-9_]{0,10}";
const ANY_NAME_PATTERN: &str = "[A-Za-z0-9_=$ .\\-éÉ名]{0,8}";
const UNSAFE_FOLDERS: [&str; 4] = ["", "relative/folder", "/", "/a/../b"];
const SANDBOX_KINDS: [SandboxKind; 3] = [
    SandboxKind::LocalProcess,
    SandboxKind::Container,
    SandboxKind::MicroVirtualMachine,
];

fn is_name_character(character: char) -> bool {
    character == '_' || character.is_ascii_alphanumeric()
}

fn is_posix_name(name: &str) -> bool {
    let mut characters = name.chars();
    let Some(first) = characters.next() else {
        return false;
    };
    let is_name_start = first == '_' || first.is_ascii_alphabetic();
    is_name_start && characters.all(is_name_character)
}

fn command_with(
    environment: BTreeMap<String, String>,
) -> CommandSpecification {
    CommandSpecification {
        program: "codex".to_owned(),
        arguments: vec!["exec".to_owned()],
        environment,
        working_directory: None,
    }
}

fn read_effective_environment(
    wrapped: &CommandSpecification,
    options: &[String],
) -> BTreeMap<String, String> {
    let mut effective = BTreeMap::new();
    for pair in options.windows(2) {
        if pair[0] != ENVIRONMENT_OPTION {
            continue;
        }
        let assignment = match pair[1].split_once('=') {
            Some((name, value)) => Some((name.to_owned(), value.to_owned())),
            None => wrapped
                .environment
                .get(&pair[1])
                .map(|value| (pair[1].clone(), value.clone())),
        };
        if let Some((name, value)) = assignment {
            effective.insert(name, value);
        }
    }
    effective
}

proptest! {
    #[test]
    fn test_ensure_valid_environment_names_property_values_stay_hidden(
        (settings, _program) in any_settings(),
        mounts in any_mounts(),
        environment in btree_map(NAME_PATTERN, SECRET_PATTERN, 0..5),
    ) {
        let command = command_with(environment.clone());

        let wrapped = wrap_in_container(&settings, &command, &mounts, &[])
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        for secret in environment.values() {
            let is_shown = wrapped
                .arguments
                .iter()
                .any(|argument| argument.contains(secret.as_str()));
            prop_assert!(!is_shown, "{secret}");
        }
        prop_assert_eq!(wrapped.environment, environment);
    }

    #[test]
    fn test_ensure_valid_environment_names_property_hosts_cannot_be_replaced(
        (settings, _program) in any_settings(),
        mounts in any_mounts(),
        hosts in any_hosts(),
        replaced_hosts in "[a-z.,*]{0,20}",
    ) {
        let name = ALLOWED_HOSTS_VARIABLE.to_owned();
        let environment = BTreeMap::from([(name, replaced_hosts)]);
        let command = command_with(environment);

        let wrapped = wrap_in_container(&settings, &command, &mounts, &hosts);

        let Ok(wrapped) = wrapped else {
            return Ok(());
        };
        let options = container_options(&wrapped, &command);
        let effective = read_effective_environment(&wrapped, options);
        let seen_hosts = effective.get(ALLOWED_HOSTS_VARIABLE);
        prop_assert_eq!(seen_hosts, Some(&hosts.join(",")));
    }

    #[test]
    fn test_ensure_valid_environment_names_property_each_name_passes_once(
        (settings, _program) in any_settings(),
        mounts in any_mounts(),
        environment in btree_map(NAME_PATTERN, SECRET_PATTERN, 0..5),
    ) {
        let command = command_with(environment.clone());

        let wrapped = wrap_in_container(&settings, &command, &mounts, &[])
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        let options = container_options(&wrapped, &command);
        let effective = read_effective_environment(&wrapped, options);
        let mut expected = environment;
        expected.insert(ALLOWED_HOSTS_VARIABLE.to_owned(), String::new());
        prop_assert_eq!(effective, expected);
    }

    #[test]
    fn test_is_valid_environment_name_property_matches_the_posix_rule(
        (settings, _program) in any_settings(),
        mounts in any_mounts(),
        name in ANY_NAME_PATTERN,
    ) {
        prop_assume!(name != ALLOWED_HOSTS_VARIABLE);
        let environment = BTreeMap::from([(name.clone(), "value".to_owned())]);
        let command = command_with(environment);

        let wrapped = wrap_in_container(&settings, &command, &mounts, &[]);

        let expected_error =
            SandboxError::InvalidEnvironmentName(name.clone());
        let is_accepted = wrapped.is_ok();
        prop_assert_eq!(is_accepted, is_posix_name(&name));
        if !is_accepted {
            prop_assert_eq!(wrapped, Err(expected_error));
        }
    }

    #[test]
    fn test_is_valid_environment_name_property_assignments_are_refused(
        (settings, _program) in any_settings(),
        mounts in any_mounts(),
        name in "[A-Z_]{1,6}",
        value in "[a-z0-9]{0,6}",
    ) {
        let assignment = format!("{name}={value}");
        let environment =
            BTreeMap::from([(assignment.clone(), "value".to_owned())]);
        let command = command_with(environment);

        let wrapped = wrap_in_container(&settings, &command, &mounts, &[]);

        let expected = SandboxError::InvalidEnvironmentName(assignment);
        prop_assert_eq!(wrapped, Err(expected));
    }

    #[test]
    fn test_is_valid_environment_name_property_mixed_case_names_pass(
        (settings, _program) in any_settings(),
        mounts in any_mounts(),
        name in "_?[a-z][A-Za-z0-9_]{0,10}",
    ) {
        let environment = BTreeMap::from([(name, "value".to_owned())]);
        let command = command_with(environment);

        let wrapped = wrap_in_container(&settings, &command, &mounts, &[]);

        prop_assert!(wrapped.is_ok());
    }

    #[test]
    fn test_wrap_with_input_options_property_unsafe_folders_fail_first(
        kind in select(SANDBOX_KINDS.to_vec()),
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        folder in select(UNSAFE_FOLDERS.to_vec()),
    ) {
        let task_folder = PathBuf::from(folder);
        let mounts = WorkspaceMounts {
            task_folder: task_folder.clone(),
            git_directories: Vec::new(),
            placeholder_mounts: Vec::new(),
        };

        let closed = wrap_in_sandbox(kind, &settings, &command, &mounts, &[]);
        let kept_open = wrap_in_sandbox_keeping_input_open(
            kind,
            &settings,
            &command,
            &mounts,
            &[],
        );

        let expected = SandboxError::UnsafeWorkspaceDirectory(task_folder);
        prop_assert_eq!(closed, Err(expected.clone()));
        prop_assert_eq!(kept_open, Err(expected));
    }

    #[test]
    fn test_wrap_with_input_options_property_micro_machines_never_open_input(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        hosts in any_hosts(),
    ) {
        let kept_open = wrap_in_sandbox_keeping_input_open(
            SandboxKind::MicroVirtualMachine,
            &settings,
            &command,
            &mounts,
            &hosts,
        );

        let expected = SandboxError::MicroVirtualMachineNotSupported;
        prop_assert_eq!(kept_open, Err(expected));
    }

    #[test]
    fn test_wrap_with_input_options_property_local_runs_replace_the_folder(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        earlier_folder in "/[a-z]{1,8}",
    ) {
        let command = CommandSpecification {
            working_directory: Some(PathBuf::from(earlier_folder)),
            ..command
        };

        let wrapped = wrap_in_sandbox_keeping_input_open(
            SandboxKind::LocalProcess,
            &settings,
            &command,
            &mounts,
            &[],
        );

        let expected = CommandSpecification {
            working_directory: Some(mounts.task_folder.clone()),
            ..command
        };
        prop_assert_eq!(wrapped, Ok(expected));
    }

    #[test]
    fn test_wrap_in_sandbox_keeping_input_open_property_one_flag_before_image(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        hosts in any_hosts(),
    ) {
        let kept_open = wrap_in_sandbox_keeping_input_open(
            SandboxKind::Container,
            &settings,
            &command,
            &mounts,
            &hosts,
        )
        .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        let options = container_options(&kept_open, &command);
        let flag_count = options
            .iter()
            .filter(|option| *option == KEEP_INPUT_OPEN_OPTION)
            .count();
        prop_assert_eq!(flag_count, 1);
        let last_option = options.last().map(String::as_str);
        prop_assert_eq!(last_option, Some(KEEP_INPUT_OPEN_OPTION));
    }
}

use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::SandboxKind;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_command::{
    PermissionAnswerer, build_agent_command, build_claude_control_command,
    choose_permission_answerer,
};
use proptest::option;
use proptest::prelude::*;

use crate::command_support::{
    any_agent, any_policy, any_prompt, any_sandbox, any_valid_session,
    build_for, contains_in_order, expected_permission_flags, expected_program,
    list_permission_flag_words,
};

const CLAUDE_FIXED_OPTIONS: [&str; 6] = [
    "-p",
    "--output-format",
    "stream-json",
    "--verbose",
    "--disallowedTools",
    "AskUserQuestion",
];
const CODEX_FIXED_OPTIONS: [&str; 2] = ["exec", "--json"];
const GEMINI_FIXED_OPTIONS: [&str; 2] = ["--output-format", "stream-json"];

fn fixed_options(agent: AgentKind) -> Vec<String> {
    let options: &[&str] = match agent {
        AgentKind::ClaudeCode => &CLAUDE_FIXED_OPTIONS,
        AgentKind::Codex => &CODEX_FIXED_OPTIONS,
        AgentKind::GeminiCli => &GEMINI_FIXED_OPTIONS,
    };
    options.iter().map(ToString::to_string).collect()
}

fn without_prompt(arguments: &[String]) -> Vec<String> {
    let option_count = arguments.len().saturating_sub(1);
    arguments[..option_count].to_vec()
}

proptest! {
    #[test]
    fn test_choose_permission_answerer_property_codex_and_gemini_use_flags(
        agent in prop_oneof![
            Just(AgentKind::Codex),
            Just(AgentKind::GeminiCli),
        ],
        approval_policy in any_policy(),
    ) {
        let answerer = choose_permission_answerer(agent, approval_policy);

        prop_assert_eq!(answerer, PermissionAnswerer::AgentFlags);
    }

    #[test]
    fn test_choose_permission_answerer_property_never_ask_uses_flags(
        agent in any_agent(),
    ) {
        let answerer =
            choose_permission_answerer(agent, ApprovalPolicy::NeverAsk);

        prop_assert_eq!(answerer, PermissionAnswerer::AgentFlags);
    }

    #[test]
    fn test_choose_permission_options_property_flags_follow_fixed_options(
        agent in any_agent(),
        sandbox in any_sandbox(),
        prompt in any_prompt(),
        session in option::of(any_valid_session()),
    ) {
        let command = build_for(agent, &prompt, session.as_deref(), sandbox)?;

        let mut expected_start = fixed_options(agent);
        expected_start.extend(expected_permission_flags(agent, sandbox));
        let start = &command.arguments[..expected_start.len()];
        prop_assert_eq!(start, expected_start.as_slice());
    }

    #[test]
    fn test_choose_permission_options_property_no_foreign_flags_appear(
        agent in any_agent(),
        sandbox in any_sandbox(),
        prompt in any_prompt(),
    ) {
        let command = build_for(agent, &prompt, None, sandbox)?;

        let own_flags = expected_permission_flags(agent, sandbox);
        let options = without_prompt(&command.arguments);
        for flag in list_permission_flag_words() {
            let is_own = own_flags.contains(&flag);
            prop_assert_eq!(options.contains(&flag), is_own, "{}", flag);
        }
        prop_assert!(contains_in_order(&options, &own_flags));
    }

    #[test]
    fn test_choose_permission_options_property_micro_vm_acts_as_container(
        agent in any_agent(),
        prompt in any_prompt(),
        session in option::of(any_valid_session()),
    ) {
        let session = session.as_deref();

        let in_micro_vm = build_agent_command(
            agent,
            &prompt,
            session,
            SandboxKind::MicroVirtualMachine,
        );
        let in_container = build_agent_command(
            agent,
            &prompt,
            session,
            SandboxKind::Container,
        );

        prop_assert_eq!(in_micro_vm, in_container);
    }

    #[test]
    fn test_to_arguments_property_fixed_options_lead_every_command(
        agent in any_agent(),
        sandbox in any_sandbox(),
        prompt in any_prompt(),
    ) {
        let command = build_for(agent, &prompt, None, sandbox)?;

        let expected = fixed_options(agent);
        let start = &command.arguments[..expected.len()];
        prop_assert_eq!(start, expected.as_slice());
    }

    #[test]
    fn test_to_arguments_property_options_never_depend_on_the_prompt(
        agent in any_agent(),
        sandbox in any_sandbox(),
        first_prompt in any_prompt(),
        second_prompt in any_prompt(),
        session in option::of(any_valid_session()),
    ) {
        let session = session.as_deref();

        let first = build_for(agent, &first_prompt, session, sandbox)?;
        let second = build_for(agent, &second_prompt, session, sandbox)?;

        prop_assert_eq!(
            without_prompt(&first.arguments),
            without_prompt(&second.arguments)
        );
    }

    #[test]
    fn test_to_arguments_property_options_are_single_words(
        agent in any_agent(),
        sandbox in any_sandbox(),
        prompt in any_prompt(),
        session in option::of(any_valid_session()),
    ) {
        let command = build_for(agent, &prompt, session.as_deref(), sandbox)?;

        for option in without_prompt(&command.arguments) {
            let is_one_word = !option.is_empty()
                && !option.chars().any(char::is_whitespace);
            prop_assert!(is_one_word, "{:?}", option);
        }
    }

    #[test]
    fn test_command_for_property_the_program_matches_the_agent(
        agent in any_agent(),
        sandbox in any_sandbox(),
        prompt in any_prompt(),
    ) {
        let command = build_for(agent, &prompt, None, sandbox)?;
        let control_command = build_claude_control_command(&prompt, None)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(command.program, expected_program(agent));
        prop_assert_eq!(control_command.command.program, "claude");
    }

    #[test]
    fn test_command_for_property_no_environment_or_folder_is_set(
        agent in any_agent(),
        sandbox in any_sandbox(),
        prompt in any_prompt(),
        session in option::of(any_valid_session()),
    ) {
        let session = session.as_deref();

        let command = build_for(agent, &prompt, session, sandbox)?;
        let control_command = build_claude_control_command(&prompt, session)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert!(command.environment.is_empty());
        prop_assert!(command.working_directory.is_none());
        prop_assert!(control_command.command.environment.is_empty());
        prop_assert!(control_command.command.working_directory.is_none());
    }

    #[test]
    fn test_command_for_property_building_twice_gives_the_same_command(
        agent in any_agent(),
        sandbox in any_sandbox(),
        prompt in any::<String>(),
        session in option::of(any::<String>()),
    ) {
        let session = session.as_deref();

        let first = build_agent_command(agent, &prompt, session, sandbox);
        let second = build_agent_command(agent, &prompt, session, sandbox);

        prop_assert_eq!(first, second);
    }
}

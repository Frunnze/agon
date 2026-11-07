use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_command::build_claude_control_command;
use proptest::option;
use proptest::prelude::*;

use crate::command_support::{
    CLAUDE_RESUME_OPTION, CODEX_RESUME_COMMAND, END_OF_OPTIONS,
    GEMINI_PROMPT_OPTION, GEMINI_RESUME_OPTION, any_prompt, any_sandbox,
    any_valid_session, build_for, count_equal, find_position,
};

const CLAUDE_PRINT_OPTION: &str = "-p";

fn resume_pair(arguments: &[String]) -> Option<(String, String)> {
    let resume_index = find_position(arguments, CLAUDE_RESUME_OPTION)?;
    let session = arguments.get(resume_index + 1)?;
    Some((CLAUDE_RESUME_OPTION.to_owned(), session.clone()))
}

fn count_starting_with(arguments: &[String], prefix: &str) -> usize {
    arguments
        .iter()
        .filter(|argument| argument.starts_with(prefix))
        .count()
}

proptest! {
    #[test]
    fn test_build_claude_command_property_prints_stream_json(
        sandbox in any_sandbox(),
        prompt in any_prompt(),
    ) {
        let command =
            build_for(AgentKind::ClaudeCode, &prompt, None, sandbox)?;

        let arguments = &command.arguments;
        let options = &arguments[..arguments.len() - 1];
        prop_assert_eq!(arguments.first().map(String::as_str), Some("-p"));
        prop_assert_eq!(count_equal(options, CLAUDE_PRINT_OPTION), 1);
        let format_index = find_position(arguments, "--output-format");
        let format = format_index.and_then(|index| arguments.get(index + 1));
        prop_assert_eq!(format.map(String::as_str), Some("stream-json"));
    }

    #[test]
    fn test_build_claude_command_property_the_prompt_follows_one_marker(
        sandbox in any_sandbox(),
        prompt in any_prompt(),
        session in option::of(any_valid_session()),
    ) {
        let command = build_for(
            AgentKind::ClaudeCode,
            &prompt,
            session.as_deref(),
            sandbox,
        )?;

        let arguments = &command.arguments;
        let marker_index = find_position(arguments, END_OF_OPTIONS);
        prop_assert_eq!(marker_index, Some(arguments.len() - 2));
        prop_assert_eq!(arguments.last(), Some(&prompt));
    }

    #[test]
    fn test_build_claude_command_property_option_like_prompts_stay_last(
        sandbox in any_sandbox(),
        prompt in "--?(resume|verbose|permission-mode|p)( [a-z]{1,6})?",
    ) {
        let command =
            build_for(AgentKind::ClaudeCode, &prompt, None, sandbox)?;

        let arguments = &command.arguments;
        let options = &arguments[..arguments.len() - 1];
        prop_assert_eq!(count_equal(options, CLAUDE_RESUME_OPTION), 0);
        prop_assert_eq!(count_equal(options, END_OF_OPTIONS), 1);
        prop_assert_eq!(arguments[arguments.len() - 2].as_str(), "--");
        prop_assert_eq!(arguments.last(), Some(&prompt));
    }

    #[test]
    fn test_describe_claude_resume_property_session_follows_the_flag(
        sandbox in any_sandbox(),
        prompt in any_prompt(),
        session in any_valid_session(),
    ) {
        let command = build_for(
            AgentKind::ClaudeCode,
            &prompt,
            Some(&session),
            sandbox,
        )?;

        let options = &command.arguments[..command.arguments.len() - 1];
        prop_assert_eq!(count_equal(options, CLAUDE_RESUME_OPTION), 1);
        let expected = (CLAUDE_RESUME_OPTION.to_owned(), session);
        prop_assert_eq!(resume_pair(options), Some(expected));
    }

    #[test]
    fn test_describe_claude_resume_property_no_session_no_resume_flag(
        sandbox in any_sandbox(),
        prompt in any_prompt(),
    ) {
        let command =
            build_for(AgentKind::ClaudeCode, &prompt, None, sandbox)?;
        let control_command = build_claude_control_command(&prompt, None)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        let options = &command.arguments[..command.arguments.len() - 1];
        prop_assert_eq!(count_equal(options, CLAUDE_RESUME_OPTION), 0);
        let control_arguments = &control_command.command.arguments;
        let control_resume_count =
            count_equal(control_arguments, CLAUDE_RESUME_OPTION);
        prop_assert_eq!(control_resume_count, 0);
    }

    #[test]
    fn test_describe_claude_resume_property_both_commands_resume_alike(
        sandbox in any_sandbox(),
        prompt in any_prompt(),
        session in any_valid_session(),
    ) {
        let command = build_for(
            AgentKind::ClaudeCode,
            &prompt,
            Some(&session),
            sandbox,
        )?;
        let control_command =
            build_claude_control_command(&prompt, Some(&session))
                .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        let control_arguments = &control_command.command.arguments;
        prop_assert_eq!(
            resume_pair(&command.arguments),
            resume_pair(control_arguments)
        );
        prop_assert!(!control_arguments.contains(&prompt));
    }

    #[test]
    fn test_build_codex_command_property_execs_with_json(
        sandbox in any_sandbox(),
        prompt in any_prompt(),
        session in option::of(any_valid_session()),
    ) {
        prop_assume!(session.as_deref() != Some("exec"));

        let command = build_for(
            AgentKind::Codex,
            &prompt,
            session.as_deref(),
            sandbox,
        )?;

        let start = &command.arguments[..2];
        prop_assert_eq!(start, &["exec".to_owned(), "--json".to_owned()]);
        let options = &command.arguments[..command.arguments.len() - 1];
        prop_assert_eq!(count_equal(options, "exec"), 1);
    }

    #[test]
    fn test_build_codex_command_property_resume_sits_before_the_marker(
        sandbox in any_sandbox(),
        prompt in any_prompt(),
        session in any_valid_session(),
    ) {
        let command =
            build_for(AgentKind::Codex, &prompt, Some(&session), sandbox)?;

        let arguments = &command.arguments;
        let length = arguments.len();
        let tail = &arguments[length - 4..];
        let expected_tail = [
            CODEX_RESUME_COMMAND.to_owned(),
            session,
            END_OF_OPTIONS.to_owned(),
            prompt,
        ];
        prop_assert_eq!(tail, &expected_tail);
    }

    #[test]
    fn test_build_codex_command_property_the_prompt_follows_one_marker(
        sandbox in any_sandbox(),
        prompt in any_prompt(),
    ) {
        let command = build_for(AgentKind::Codex, &prompt, None, sandbox)?;

        let arguments = &command.arguments;
        let options = &arguments[..arguments.len() - 1];
        prop_assert_eq!(count_equal(options, END_OF_OPTIONS), 1);
        prop_assert_eq!(count_equal(options, CODEX_RESUME_COMMAND), 0);
        prop_assert_eq!(arguments.last(), Some(&prompt));
    }

    #[test]
    fn test_build_gemini_command_property_prompt_is_one_prompt_option(
        sandbox in any_sandbox(),
        prompt in any_prompt(),
        session in option::of(any_valid_session()),
    ) {
        let command = build_for(
            AgentKind::GeminiCli,
            &prompt,
            session.as_deref(),
            sandbox,
        )?;

        let arguments = &command.arguments;
        let expected_last = format!("{GEMINI_PROMPT_OPTION}{prompt}");
        prop_assert_eq!(arguments.last(), Some(&expected_last));
        prop_assert_eq!(count_equal(arguments, END_OF_OPTIONS), 0);
        let options = &arguments[..arguments.len() - 1];
        prop_assert_eq!(count_starting_with(options, GEMINI_PROMPT_OPTION), 0);
    }

    #[test]
    fn test_build_gemini_command_property_resume_is_one_argument(
        sandbox in any_sandbox(),
        prompt in any_prompt(),
        session in option::of(any_valid_session()),
    ) {
        let command = build_for(
            AgentKind::GeminiCli,
            &prompt,
            session.as_deref(),
            sandbox,
        )?;

        let arguments = &command.arguments;
        let options = &arguments[..arguments.len() - 1];
        let resume_count = count_starting_with(options, GEMINI_RESUME_OPTION);
        prop_assert_eq!(resume_count, usize::from(session.is_some()));
        if let Some(session) = session {
            let expected = format!("{GEMINI_RESUME_OPTION}{session}");
            prop_assert!(options.contains(&expected));
        }
    }

    #[test]
    fn test_build_gemini_command_property_argument_count_ignores_prompt(
        sandbox in any_sandbox(),
        first_prompt in any_prompt(),
        second_prompt in any_prompt(),
    ) {
        let first =
            build_for(AgentKind::GeminiCli, &first_prompt, None, sandbox)?;
        let second =
            build_for(AgentKind::GeminiCli, &second_prompt, None, sandbox)?;

        prop_assert_eq!(first.arguments.len(), second.arguments.len());
    }
}

use std::collections::BTreeMap;

use orchestration_core::device::SandboxKind;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_command::{
    AgentCommandError, build_agent_command,
};
use orchestration_hub::command_specification::CommandSpecification;
use proptest::prelude::*;

const SHELL_PROGRAMS: [&str; 5] = ["sh", "bash", "zsh", "cmd", "powershell"];

fn any_agent() -> impl Strategy<Value = AgentKind> {
    prop_oneof![
        Just(AgentKind::ClaudeCode),
        Just(AgentKind::Codex),
        Just(AgentKind::GeminiCli),
    ]
}

fn any_prompt() -> impl Strategy<Value = String> {
    let hostile_prompt = "[-;&|$`'\"()<> a-z\n*]{1,40}";
    prop_oneof![any::<String>(), hostile_prompt.prop_map(String::from)]
        .prop_filter("a prompt has text", |prompt| !prompt.trim().is_empty())
}

fn any_session() -> impl Strategy<Value = String> {
    "[a-f0-9]{1,8}(-[a-f0-9]{1,12}){0,4}"
}

fn any_invalid_session() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(String::new()),
        "-[a-z0-9-]{0,10}",
        "[a-z0-9]{0,5}[^a-zA-Z0-9-][a-z0-9]{0,5}",
    ]
}

fn expected_command(
    program: &str,
    arguments: Vec<String>,
) -> CommandSpecification {
    CommandSpecification {
        program: program.to_string(),
        arguments,
        environment: BTreeMap::new(),
        working_directory: None,
    }
}

fn to_strings(words: &[&str]) -> Vec<String> {
    words.iter().map(ToString::to_string).collect()
}

proptest! {
    #[test]
    fn test_build_agent_command_property_claude_arguments_are_exact(
        prompt in any_prompt(),
        session in proptest::option::of(any_session()),
    ) {
        let mut arguments = to_strings(
            &[
                "-p",
                "--output-format",
                "stream-json",
                "--verbose",
                "--disallowedTools",
                "AskUserQuestion",
                "--permission-mode",
                "auto",
            ],
        );
        if let Some(session) = &session {
            arguments.extend(to_strings(&["--resume", session]));
        }
        arguments.extend(to_strings(&["--", &prompt]));

        let command = build_agent_command(
            AgentKind::ClaudeCode,
            &prompt,
            session.as_deref(),
            SandboxKind::LocalProcess,
        );

        prop_assert_eq!(command, Ok(expected_command("claude", arguments)));
    }

    #[test]
    fn test_build_agent_command_property_codex_arguments_are_exact(
        prompt in any_prompt(),
        session in proptest::option::of(any_session()),
    ) {
        let mut arguments =
            to_strings(&["exec", "--json", "--sandbox", "workspace-write"]);
        if let Some(session) = &session {
            arguments.extend(to_strings(&["resume", session]));
        }
        arguments.extend(to_strings(&["--", &prompt]));

        let command = build_agent_command(
            AgentKind::Codex,
            &prompt,
            session.as_deref(),
            SandboxKind::LocalProcess,
        );

        prop_assert_eq!(command, Ok(expected_command("codex", arguments)));
    }

    #[test]
    fn test_build_agent_command_property_gemini_arguments_are_exact(
        prompt in any_prompt(),
        session in proptest::option::of(any_session()),
    ) {
        let mut arguments = to_strings(&[
            "--output-format",
            "stream-json",
            "--approval-mode",
            "auto_edit",
        ]);
        if let Some(session) = &session {
            arguments.push(format!("--resume={session}"));
        }
        arguments.push(format!("--prompt={prompt}"));

        let command = build_agent_command(
            AgentKind::GeminiCli,
            &prompt,
            session.as_deref(),
            SandboxKind::LocalProcess,
        );

        prop_assert_eq!(command, Ok(expected_command("gemini", arguments)));
    }

    #[test]
    fn test_build_agent_command_property_prompt_is_one_unchanged_argument(
        agent in any_agent(),
        prompt in any_prompt(),
    ) {
        let command =
            build_agent_command(agent, &prompt, None, SandboxKind::Container)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        let last_argument = command.arguments.last().cloned();
        let prompt_option = format!("--prompt={prompt}");
        let is_prompt_last = last_argument
            .is_some_and(|last| last == prompt || last == prompt_option);

        prop_assert!(is_prompt_last);
        prop_assert!(!SHELL_PROGRAMS.contains(&command.program.as_str()));
        prop_assert!(!command.arguments.contains(&"-c".to_string()));
    }

    #[test]
    fn test_build_agent_command_property_blank_prompt_is_rejected(
        agent in any_agent(),
        prompt in "[ \t\n\r]{0,8}",
    ) {
        let command =
            build_agent_command(agent, &prompt, None, SandboxKind::Container);

        prop_assert_eq!(command, Err(AgentCommandError::EmptyPrompt));
    }

    #[test]
    fn test_build_agent_command_property_invalid_session_is_rejected(
        agent in any_agent(),
        prompt in any_prompt(),
        session in any_invalid_session(),
    ) {
        let command = build_agent_command(
            agent,
            &prompt,
            Some(&session),
            SandboxKind::LocalProcess,
        );

        prop_assert_eq!(
            command,
            Err(AgentCommandError::InvalidSession(session)),
        );
    }
}

use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::SandboxKind;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_command::{
    AgentCommandError, PermissionAnswerer, build_agent_command,
    build_claude_control_command, choose_permission_answerer,
};
use orchestration_hub::claude_control::write_user_message;
use proptest::prelude::*;

const FULL_ACCESS_FLAGS: [&str; 3] = [
    "--dangerously-skip-permissions",
    "--dangerously-bypass-approvals-and-sandbox",
    "yolo",
];

fn any_agent() -> impl Strategy<Value = AgentKind> {
    prop_oneof![
        Just(AgentKind::ClaudeCode),
        Just(AgentKind::Codex),
        Just(AgentKind::GeminiCli),
    ]
}

fn any_isolated_sandbox() -> impl Strategy<Value = SandboxKind> {
    prop_oneof![
        Just(SandboxKind::Container),
        Just(SandboxKind::MicroVirtualMachine),
    ]
}

fn any_prompt() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9 .,]{1,40}"
        .prop_filter("prompt has content", |text| !text.trim().is_empty())
}

fn full_access_flag(agent: AgentKind) -> Vec<&'static str> {
    match agent {
        AgentKind::ClaudeCode => vec!["--dangerously-skip-permissions"],
        AgentKind::Codex => vec!["--dangerously-bypass-approvals-and-sandbox"],
        AgentKind::GeminiCli => vec!["--approval-mode", "yolo"],
    }
}

fn any_policy() -> impl Strategy<Value = ApprovalPolicy> {
    prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ]
}

fn any_session() -> impl Strategy<Value = String> {
    "[a-f0-9]{1,8}(-[a-f0-9]{1,12}){0,4}"
}

fn local_flag(agent: AgentKind) -> Vec<&'static str> {
    match agent {
        AgentKind::ClaudeCode => vec!["--permission-mode", "auto"],
        AgentKind::Codex => vec!["--sandbox", "workspace-write"],
        AgentKind::GeminiCli => vec!["--approval-mode", "auto_edit"],
    }
}

fn contains_in_order(arguments: &[String], expected: &[&str]) -> bool {
    arguments
        .windows(expected.len())
        .any(|window| window == expected)
}

proptest! {
    #[test]
    fn test_build_agent_command_property_isolated_agents_get_full_access(
        agent in any_agent(),
        sandbox in any_isolated_sandbox(),
        prompt in any_prompt(),
    ) {
        let command = build_agent_command(agent, &prompt, None, sandbox);

        let Ok(command) = command else {
            return Err(TestCaseError::fail(format!("{command:?}")));
        };
        let expected = full_access_flag(agent);
        prop_assert!(contains_in_order(&command.arguments, &expected));
    }

    #[test]
    fn test_build_agent_command_property_local_agents_never_get_full_access(
        agent in any_agent(),
        prompt in any_prompt(),
    ) {
        let command = build_agent_command(
            agent,
            &prompt,
            None,
            SandboxKind::LocalProcess,
        );

        let Ok(command) = command else {
            return Err(TestCaseError::fail(format!("{command:?}")));
        };
        let expected = local_flag(agent);
        prop_assert!(contains_in_order(&command.arguments, &expected));
        for flag in FULL_ACCESS_FLAGS {
            let has_flag =
                command.arguments.iter().any(|argument| argument == flag);
            prop_assert!(!has_flag);
        }
    }

    #[test]
    fn test_build_agent_command_property_prompt_stays_the_last_argument(
        agent in any_agent(),
        prompt in any_prompt(),
        isolated in any::<bool>(),
    ) {
        let sandbox = if isolated {
            SandboxKind::Container
        } else {
            SandboxKind::LocalProcess
        };

        let command = build_agent_command(agent, &prompt, None, sandbox);

        let Ok(command) = command else {
            return Err(TestCaseError::fail(format!("{command:?}")));
        };
        let last = command.arguments.last().cloned().unwrap_or_default();
        prop_assert!(last.ends_with(prompt.as_str()));
    }
}

proptest! {
    #[test]
    fn test_choose_permission_answerer_property_only_asking_claude_asks(
        agent in any_agent(),
        approval_policy in any_policy(),
    ) {
        let answerer = choose_permission_answerer(agent, approval_policy);

        let asks_the_person = agent == AgentKind::ClaudeCode
            && approval_policy == ApprovalPolicy::AskBeforeRiskyActions;
        let expected = if asks_the_person {
            PermissionAnswerer::Person
        } else {
            PermissionAnswerer::AgentFlags
        };
        prop_assert_eq!(answerer, expected);
    }

    #[test]
    fn test_build_claude_control_command_property_arguments_are_exact(
        prompt in any_prompt(),
        session in proptest::option::of(any_session()),
    ) {
        let mut expected: Vec<String> = [
            "-p",
            "--input-format",
            "stream-json",
            "--output-format",
            "stream-json",
            "--verbose",
            "--disallowedTools",
            "AskUserQuestion",
            "--permission-prompt-tool",
            "stdio",
            "--permission-mode",
            "acceptEdits",
        ]
        .iter()
        .map(ToString::to_string)
        .collect();
        if let Some(session) = &session {
            expected.push("--resume".to_string());
            expected.push(session.clone());
        }

        let control_command =
            build_claude_control_command(&prompt, session.as_deref())
                .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(control_command.command.program, "claude");
        prop_assert_eq!(control_command.command.arguments, expected);
        let expected_prompt_line = write_user_message(&prompt);
        prop_assert_eq!(control_command.prompt_line, expected_prompt_line);
    }

    #[test]
    fn test_build_claude_control_command_property_rejects_blank_prompts(
        prompt in "[ \t\n\r]{0,8}",
    ) {
        let control_command = build_claude_control_command(&prompt, None);

        prop_assert_eq!(control_command, Err(AgentCommandError::EmptyPrompt));
    }

    #[test]
    fn test_build_claude_control_command_property_rejects_option_sessions(
        prompt in any_prompt(),
        session in "-[a-z0-9-]{0,10}",
    ) {
        let command = build_claude_control_command(&prompt, Some(&session));

        let expected = AgentCommandError::InvalidSession(session);
        prop_assert_eq!(command, Err(expected));
    }
}

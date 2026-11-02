use orchestration_core::device::SandboxKind;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_command::build_agent_command;
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

fn edit_only_flag(agent: AgentKind) -> Vec<&'static str> {
    match agent {
        AgentKind::ClaudeCode => vec!["--permission-mode", "acceptEdits"],
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
    fn test_build_agent_command_property_local_agents_only_edit_files(
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
        let expected = edit_only_flag(agent);
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

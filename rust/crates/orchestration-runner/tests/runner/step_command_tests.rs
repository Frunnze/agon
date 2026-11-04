use std::collections::BTreeMap;
use std::path::PathBuf;

use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::SandboxKind;
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_command::AgentCommandError;
use orchestration_hub::claude_control::write_user_message;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use orchestration_runner::agent_sandbox::AgentSandbox;
use orchestration_runner::step_command::{
    StepCommand, StepCommandError, build_step_command,
};
use proptest::prelude::*;

use crate::fake_agent::test_container;
use crate::support::to_case_error;

const TASK_FOLDER: &str = "/runner/worktrees/fix-the-build";
const RESUME_OPTION: &str = "--resume";
const SKIP_PERMISSIONS_OPTION: &str = "--dangerously-skip-permissions";
const AUTO_MODE_OPTIONS: [&str; 2] = ["--permission-mode", "auto"];
const HOST_ANSWERS_OPTIONS: [&str; 2] = ["--permission-prompt-tool", "stdio"];
const ACCEPT_EDITS_OPTIONS: [&str; 2] = ["--permission-mode", "acceptEdits"];
const KEEP_INPUT_OPEN_OPTION: &str = "--interactive";

fn sandbox_of(kind: SandboxKind) -> AgentSandbox {
    AgentSandbox {
        kind,
        container: test_container(),
        allowed_hosts: vec!["api.anthropic.com".to_string()],
        environment: BTreeMap::from([(
            "ANTHROPIC_API_KEY".to_string(),
            "test-key".to_string(),
        )]),
    }
}

fn task_mounts() -> WorkspaceMounts {
    WorkspaceMounts {
        task_folder: PathBuf::from(TASK_FOLDER),
        git_directories: Vec::new(),
        placeholder_mounts: Vec::new(),
    }
}

fn no_protected_files() -> ProtectedFiles {
    ProtectedFiles {
        patterns: Vec::new(),
    }
}

fn any_session() -> impl Strategy<Value = String> {
    "[a-z0-9]{1,8}(-[a-z0-9]{1,8}){0,4}"
}

fn any_chat_text() -> impl Strategy<Value = String> {
    any::<String>()
        .prop_filter("the text is not blank", |text| !text.trim().is_empty())
}

fn any_prompt() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9 .,]{1,40}"
        .prop_filter("prompt has content", |text| !text.trim().is_empty())
}

fn prompt_argument_command(
    step_command: StepCommand,
) -> Result<CommandSpecification, TestCaseError> {
    match step_command {
        StepCommand::PromptInArguments(command) => Ok(command),
        StepCommand::PromptOnInput(_) => {
            Err(TestCaseError::fail("the prompt went to the input"))
        }
    }
}

fn contains_in_order(arguments: &[String], expected: &[&str]) -> bool {
    arguments
        .windows(expected.len())
        .any(|window| window == expected)
}

fn any_sandbox_kind() -> impl Strategy<Value = SandboxKind> {
    prop_oneof![
        Just(SandboxKind::LocalProcess),
        Just(SandboxKind::Container)
    ]
}

proptest! {
    #[test]
    fn test_build_step_command_property_resumes_with_the_exact_chat_text(
        chat_text in any_chat_text(),
        session in any_session(),
        kind in any_sandbox_kind(),
    ) {
        let sandbox = sandbox_of(kind);

        let step_command = build_step_command(
            &sandbox,
            &task_mounts(),
            AgentKind::ClaudeCode,
            ApprovalPolicy::NeverAsk,
            &no_protected_files(),
            &chat_text,
            Some(&session),
        ).map_err(to_case_error)?;
        let command = prompt_argument_command(step_command)?;

        prop_assert_eq!(command.arguments.last(), Some(&chat_text));
        let resume_position = command
            .arguments
            .iter()
            .position(|argument| argument == RESUME_OPTION);
        let session_position = resume_position.map(|position| position + 1);
        let given_session = session_position
            .and_then(|position| command.arguments.get(position));
        prop_assert_eq!(given_session, Some(&session));
        prop_assert_eq!(&command.environment, &sandbox.environment);
        if kind == SandboxKind::LocalProcess {
            let task_folder = PathBuf::from(TASK_FOLDER);
            prop_assert_eq!(command.working_directory, Some(task_folder));
        }
    }

    #[test]
    fn test_build_step_command_property_never_panics_on_any_text(
        chat_text in any::<String>(),
        session in any::<String>(),
        kind in any_sandbox_kind(),
    ) {
        let built = build_step_command(
            &sandbox_of(kind),
            &task_mounts(),
            AgentKind::ClaudeCode,
            ApprovalPolicy::NeverAsk,
            &no_protected_files(),
            &chat_text,
            Some(&session),
        );

        match built {
            Ok(step_command) => {
                let command = prompt_argument_command(step_command)?;
                prop_assert_eq!(command.arguments.last(), Some(&chat_text));
            }
            Err(StepCommandError::Agent(
                AgentCommandError::EmptyPrompt
                | AgentCommandError::InvalidSession(_),
            )) => {}
            Err(problem) => {
                return Err(TestCaseError::fail(problem.to_string()));
            }
        }
    }
}

fn build_claude_step(
    approval_policy: ApprovalPolicy,
    kind: SandboxKind,
    prompt: &str,
) -> Result<StepCommand, TestCaseError> {
    build_step_command(
        &sandbox_of(kind),
        &task_mounts(),
        AgentKind::ClaudeCode,
        approval_policy,
        &no_protected_files(),
        prompt,
        None,
    )
    .map_err(to_case_error)
}

fn has_argument(arguments: &[String], wanted: &str) -> bool {
    arguments.iter().any(|argument| argument == wanted)
}

proptest! {
    #[test]
    fn test_build_step_command_property_asking_claude_takes_prompt_on_input(
        kind in any_sandbox_kind(),
        prompt in any_prompt(),
    ) {
        let asking = ApprovalPolicy::AskBeforeRiskyActions;

        let step_command = build_claude_step(asking, kind, &prompt)?;

        let StepCommand::PromptOnInput(control) = step_command else {
            return Err(TestCaseError::fail("the prompt is an argument"));
        };
        let arguments = &control.command.arguments;
        let is_isolated = kind == SandboxKind::Container;
        let expected_prompt_line = write_user_message(&prompt);
        prop_assert_eq!(&control.prompt_line, &expected_prompt_line);
        prop_assert!(!arguments.contains(&prompt));
        prop_assert!(contains_in_order(arguments, &HOST_ANSWERS_OPTIONS));
        prop_assert!(contains_in_order(arguments, &ACCEPT_EDITS_OPTIONS));
        prop_assert!(!contains_in_order(arguments, &AUTO_MODE_OPTIONS));
        prop_assert!(!has_argument(arguments, SKIP_PERMISSIONS_OPTION));
        let keeps_input_open = has_argument(arguments, KEEP_INPUT_OPEN_OPTION);
        prop_assert_eq!(keeps_input_open, is_isolated);
    }

    #[test]
    fn test_build_step_command_property_silent_claude_uses_place_flags(
        kind in any_sandbox_kind(),
        prompt in any_prompt(),
    ) {
        let silent = ApprovalPolicy::NeverAsk;

        let step_command = build_claude_step(silent, kind, &prompt)?;

        let command = prompt_argument_command(step_command)?;
        let arguments = &command.arguments;
        let is_isolated = kind == SandboxKind::Container;
        prop_assert_eq!(arguments.last(), Some(&prompt));
        prop_assert!(!contains_in_order(arguments, &HOST_ANSWERS_OPTIONS));
        prop_assert!(!has_argument(arguments, KEEP_INPUT_OPEN_OPTION));
        let skips_permissions =
            has_argument(arguments, SKIP_PERMISSIONS_OPTION);
        prop_assert_eq!(skips_permissions, is_isolated);
        let uses_auto_mode = contains_in_order(arguments, &AUTO_MODE_OPTIONS);
        prop_assert_eq!(uses_auto_mode, !is_isolated);
    }

    #[test]
    fn test_build_step_command_property_other_agents_ignore_the_policy(
        agent in prop_oneof![
            Just(AgentKind::Codex),
            Just(AgentKind::GeminiCli),
        ],
        kind in any_sandbox_kind(),
        prompt in any_prompt(),
    ) {
        let sandbox = sandbox_of(kind);
        let mounts = task_mounts();
        let asking = ApprovalPolicy::AskBeforeRiskyActions;
        let silent = ApprovalPolicy::NeverAsk;

        let when_asking =
            build_step_command(
                &sandbox,
                &mounts,
                agent,
                asking,
                &no_protected_files(),
                &prompt,
                None,
            )
            .map_err(to_case_error)?;
        let when_silent =
            build_step_command(
                &sandbox,
                &mounts,
                agent,
                silent,
                &no_protected_files(),
                &prompt,
                None,
            )
            .map_err(to_case_error)?;

        let command = prompt_argument_command(when_asking.clone())?;
        let last_argument = command.arguments.last().cloned();
        let ends_with_prompt = last_argument
            .is_some_and(|last| last.ends_with(prompt.as_str()));
        prop_assert!(ends_with_prompt);
        prop_assert_eq!(when_asking, when_silent);
    }
}

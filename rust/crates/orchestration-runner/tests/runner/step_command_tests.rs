use std::collections::BTreeMap;
use std::path::PathBuf;

use orchestration_core::device::SandboxKind;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_command::AgentCommandError;
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use orchestration_runner::agent_sandbox::AgentSandbox;
use orchestration_runner::step_command::{
    StepCommandError, build_step_command,
};
use proptest::prelude::*;

use crate::fake_agent::test_container;
use crate::support::to_case_error;

const TASK_FOLDER: &str = "/runner/worktrees/fix-the-build";
const RESUME_OPTION: &str = "--resume";

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
    }
}

fn any_session() -> impl Strategy<Value = String> {
    "[a-z0-9]{1,8}(-[a-z0-9]{1,8}){0,4}"
}

fn any_chat_text() -> impl Strategy<Value = String> {
    any::<String>()
        .prop_filter("the text is not blank", |text| !text.trim().is_empty())
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

        let command = build_step_command(
            &sandbox,
            &task_mounts(),
            AgentKind::ClaudeCode,
            &chat_text,
            Some(&session),
        ).map_err(to_case_error)?;

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
            &chat_text,
            Some(&session),
        );

        match built {
            Ok(command) => {
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

use std::collections::BTreeMap;
use std::path::PathBuf;

use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::SandboxKind;
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::protected_files_settings::SETTINGS_OPTION;
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use orchestration_runner::agent_sandbox::AgentSandbox;
use orchestration_runner::step_command::{
    StepCommand, StepCommandError, build_step_command,
};
use proptest::collection::btree_set;
use proptest::prelude::*;
use serde_json::Value;

use crate::fake_agent::test_container;
use crate::support::to_case_error;

const TASK_FOLDER: &str = "/runner/worktrees/keep-secrets";
const PROMPT: &str = "Fix the build";

fn sandbox_of(kind: SandboxKind) -> AgentSandbox {
    AgentSandbox {
        kind,
        container: test_container(),
        allowed_hosts: vec!["api.anthropic.com".to_string()],
        environment: BTreeMap::new(),
    }
}

fn task_mounts() -> WorkspaceMounts {
    WorkspaceMounts {
        task_folder: PathBuf::from(TASK_FOLDER),
        git_directories: Vec::new(),
        placeholder_mounts: Vec::new(),
    }
}

fn any_protected_files() -> impl Strategy<Value = ProtectedFiles> {
    btree_set("~/\\.[a-z]{1,8}|[a-z]{1,8}\\.pem|\\.env(\\.\\*)?", 1..6)
        .prop_map(|patterns| ProtectedFiles {
            patterns: patterns.into_iter().collect(),
        })
}

fn no_protected_files() -> ProtectedFiles {
    ProtectedFiles {
        patterns: Vec::new(),
    }
}

fn any_policy() -> impl Strategy<Value = ApprovalPolicy> {
    prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ]
}

fn any_sandbox_kind() -> impl Strategy<Value = SandboxKind> {
    prop_oneof![
        Just(SandboxKind::LocalProcess),
        Just(SandboxKind::Container)
    ]
}

fn any_other_agent() -> impl Strategy<Value = AgentKind> {
    prop_oneof![Just(AgentKind::Codex), Just(AgentKind::GeminiCli)]
}

fn command_arguments(step_command: &StepCommand) -> &[String] {
    match step_command {
        StepCommand::PromptInArguments(command) => &command.arguments,
        StepCommand::PromptOnInput(control) => &control.command.arguments,
    }
}

fn read_deny_rules(arguments: &[String]) -> Vec<String> {
    let settings_position = arguments
        .iter()
        .position(|argument| argument == SETTINGS_OPTION);
    let settings_text = settings_position
        .and_then(|position| arguments.get(position + 1))
        .cloned()
        .unwrap_or_default();
    let settings: Value =
        serde_json::from_str(&settings_text).unwrap_or(Value::Null);
    let deny_rules = settings["permissions"]["deny"].as_array().cloned();
    deny_rules
        .unwrap_or_default()
        .iter()
        .filter_map(|rule| rule.as_str().map(ToString::to_string))
        .collect()
}

fn names_pattern(deny_rules: &[String], pattern: &str) -> bool {
    let inside_home = pattern.strip_prefix("~/");
    let rule_path = match inside_home {
        Some(inside_home) => format!("~/{inside_home}"),
        None => format!("**/{pattern}"),
    };
    let read_rule = format!("Read({rule_path})");
    deny_rules.contains(&read_rule)
}

proptest! {
    #[test]
    fn test_build_step_command_property_claude_gets_every_pattern(
        protected in any_protected_files(),
        approval_policy in any_policy(),
        kind in any_sandbox_kind(),
    ) {
        let step_command = build_step_command(
            &sandbox_of(kind),
            &task_mounts(),
            AgentKind::ClaudeCode,
            approval_policy,
            &protected,
            PROMPT,
            None,
        )
        .map_err(to_case_error)?;

        let deny_rules = read_deny_rules(command_arguments(&step_command));
        prop_assert!(!deny_rules.is_empty());
        for pattern in &protected.patterns {
            prop_assert!(names_pattern(&deny_rules, pattern), "{pattern}");
        }
    }

    #[test]
    fn test_build_step_command_property_other_agents_need_a_container(
        agent in any_other_agent(),
        protected in any_protected_files(),
        approval_policy in any_policy(),
    ) {
        let refused = build_step_command(
            &sandbox_of(SandboxKind::LocalProcess),
            &task_mounts(),
            agent,
            approval_policy,
            &protected,
            PROMPT,
            None,
        );

        let Err(StepCommandError::FilesCannotBeProtected { .. }) = &refused
        else {
            return Err(TestCaseError::fail(format!("{refused:?}")));
        };
        let reason = refused.err().map(|problem| problem.to_string());
        let reason = reason.unwrap_or_default();
        prop_assert!(reason.contains("Docker"), "{reason}");
    }

    #[test]
    fn test_build_step_command_property_other_agents_run_in_containers(
        agent in any_other_agent(),
        protected in any_protected_files(),
        approval_policy in any_policy(),
    ) {
        let step_command = build_step_command(
            &sandbox_of(SandboxKind::Container),
            &task_mounts(),
            agent,
            approval_policy,
            &protected,
            PROMPT,
            None,
        )
        .map_err(to_case_error)?;

        let arguments = command_arguments(&step_command);
        prop_assert!(!arguments.iter().any(|item| item == SETTINGS_OPTION));
    }

    #[test]
    fn test_build_step_command_property_empty_list_lets_every_agent_run(
        agent in prop_oneof![
            Just(AgentKind::ClaudeCode),
            Just(AgentKind::Codex),
            Just(AgentKind::GeminiCli),
        ],
        approval_policy in any_policy(),
        kind in any_sandbox_kind(),
    ) {
        let step_command = build_step_command(
            &sandbox_of(kind),
            &task_mounts(),
            agent,
            approval_policy,
            &no_protected_files(),
            PROMPT,
            None,
        )
        .map_err(to_case_error)?;

        let arguments = command_arguments(&step_command);
        prop_assert!(!arguments.iter().any(|item| item == SETTINGS_OPTION));
    }
}

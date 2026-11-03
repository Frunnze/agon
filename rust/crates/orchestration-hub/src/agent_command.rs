use std::collections::BTreeMap;

use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::SandboxKind;
use orchestration_core::workflow::AgentKind;
use thiserror::Error;

use crate::claude_control::write_user_message;
use crate::command_specification::CommandSpecification;

pub const CLAUDE_PROGRAM: &str = "claude";
const CLAUDE_OPTIONS: [&str; 6] = [
    "-p",
    "--output-format",
    "stream-json",
    "--verbose",
    "--disallowedTools",
    "AskUserQuestion",
];
const CLAUDE_CONTROL_OPTIONS: [&str; 12] = [
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
];
const CLAUDE_RESUME_OPTION: &str = "--resume";
const CODEX_PROGRAM: &str = "codex";
const CODEX_OPTIONS: [&str; 2] = ["exec", "--json"];
const CODEX_RESUME_COMMAND: &str = "resume";
const GEMINI_PROGRAM: &str = "gemini";
const GEMINI_OPTIONS: [&str; 2] = ["--output-format", "stream-json"];
const GEMINI_RESUME_OPTION: &str = "--resume=";
const GEMINI_PROMPT_OPTION: &str = "--prompt=";
const END_OF_OPTIONS: &str = "--";
const CLAUDE_FULL_ACCESS: &[&str] = &["--dangerously-skip-permissions"];
const CLAUDE_AUTO_MODE: &[&str] = &["--permission-mode", "auto"];
const CODEX_FULL_ACCESS: &[&str] =
    &["--dangerously-bypass-approvals-and-sandbox"];
const CODEX_EDIT_ONLY: &[&str] = &["--sandbox", "workspace-write"];
const GEMINI_FULL_ACCESS: &[&str] = &["--approval-mode", "yolo"];
const GEMINI_EDIT_ONLY: &[&str] = &["--approval-mode", "auto_edit"];
const SESSION_SEPARATOR: char = '-';

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PermissionAnswerer {
    AgentFlags,
    Person,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ClaudeControlCommand {
    pub command: CommandSpecification,
    pub prompt_line: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum AgentCommandError {
    #[error("the prompt is empty")]
    EmptyPrompt,
    #[error("the session id {0:?} is not valid")]
    InvalidSession(String),
}

pub fn build_agent_command(
    agent: AgentKind,
    prompt: &str,
    session: Option<&str>,
    sandbox: SandboxKind,
) -> Result<CommandSpecification, AgentCommandError> {
    ensure_prompt_has_text(prompt)?;

    let permissions = choose_permission_options(agent, sandbox);
    match agent {
        AgentKind::ClaudeCode => {
            build_claude_command(prompt, session, permissions)
        }
        AgentKind::Codex => build_codex_command(prompt, session, permissions),
        AgentKind::GeminiCli => {
            build_gemini_command(prompt, session, permissions)
        }
    }
}

#[must_use]
pub fn choose_permission_answerer(
    agent: AgentKind,
    approval_policy: ApprovalPolicy,
) -> PermissionAnswerer {
    let asks_before_risky_actions =
        approval_policy == ApprovalPolicy::AskBeforeRiskyActions;
    if agent == AgentKind::ClaudeCode && asks_before_risky_actions {
        return PermissionAnswerer::Person;
    }
    PermissionAnswerer::AgentFlags
}

pub fn build_claude_control_command(
    prompt: &str,
    session: Option<&str>,
) -> Result<ClaudeControlCommand, AgentCommandError> {
    ensure_prompt_has_text(prompt)?;

    let mut arguments = to_arguments(&CLAUDE_CONTROL_OPTIONS);
    arguments.extend(describe_claude_resume(session)?);
    Ok(ClaudeControlCommand {
        command: command_for(CLAUDE_PROGRAM, arguments),
        prompt_line: write_user_message(prompt),
    })
}

fn choose_permission_options(
    agent: AgentKind,
    sandbox: SandboxKind,
) -> &'static [&'static str] {
    let is_isolated = matches!(
        sandbox,
        SandboxKind::Container | SandboxKind::MicroVirtualMachine
    );
    match (agent, is_isolated) {
        (AgentKind::ClaudeCode, true) => CLAUDE_FULL_ACCESS,
        (AgentKind::ClaudeCode, false) => CLAUDE_AUTO_MODE,
        (AgentKind::Codex, true) => CODEX_FULL_ACCESS,
        (AgentKind::Codex, false) => CODEX_EDIT_ONLY,
        (AgentKind::GeminiCli, true) => GEMINI_FULL_ACCESS,
        (AgentKind::GeminiCli, false) => GEMINI_EDIT_ONLY,
    }
}

fn build_claude_command(
    prompt: &str,
    session: Option<&str>,
    permissions: &[&str],
) -> Result<CommandSpecification, AgentCommandError> {
    let mut arguments = to_arguments(&CLAUDE_OPTIONS);
    arguments.extend(to_arguments(permissions));
    arguments.extend(describe_claude_resume(session)?);

    arguments.push(END_OF_OPTIONS.to_string());
    arguments.push(prompt.to_string());
    Ok(command_for(CLAUDE_PROGRAM, arguments))
}

fn describe_claude_resume(
    session: Option<&str>,
) -> Result<Vec<String>, AgentCommandError> {
    let Some(session) = check_session(session)? else {
        return Ok(Vec::new());
    };
    Ok(vec![CLAUDE_RESUME_OPTION.to_string(), session.to_string()])
}

fn build_codex_command(
    prompt: &str,
    session: Option<&str>,
    permissions: &[&str],
) -> Result<CommandSpecification, AgentCommandError> {
    let mut arguments = to_arguments(&CODEX_OPTIONS);
    arguments.extend(to_arguments(permissions));
    if let Some(session) = check_session(session)? {
        arguments.push(CODEX_RESUME_COMMAND.to_string());
        arguments.push(session.to_string());
    }

    arguments.push(END_OF_OPTIONS.to_string());
    arguments.push(prompt.to_string());
    Ok(command_for(CODEX_PROGRAM, arguments))
}

fn build_gemini_command(
    prompt: &str,
    session: Option<&str>,
    permissions: &[&str],
) -> Result<CommandSpecification, AgentCommandError> {
    let mut arguments = to_arguments(&GEMINI_OPTIONS);
    arguments.extend(to_arguments(permissions));
    if let Some(session) = check_session(session)? {
        arguments.push(format!("{GEMINI_RESUME_OPTION}{session}"));
    }

    arguments.push(format!("{GEMINI_PROMPT_OPTION}{prompt}"));
    Ok(command_for(GEMINI_PROGRAM, arguments))
}

fn ensure_prompt_has_text(prompt: &str) -> Result<(), AgentCommandError> {
    if prompt.trim().is_empty() {
        return Err(AgentCommandError::EmptyPrompt);
    }
    Ok(())
}

fn check_session(
    session: Option<&str>,
) -> Result<Option<&str>, AgentCommandError> {
    let Some(session) = session else {
        return Ok(None);
    };
    if !is_valid_session(session) {
        return Err(AgentCommandError::InvalidSession(session.into()));
    }
    Ok(Some(session))
}

fn is_valid_session(session: &str) -> bool {
    let has_only_session_characters = session.chars().all(|character| {
        character.is_ascii_alphanumeric() || character == SESSION_SEPARATOR
    });
    let starts_like_an_option = session.starts_with(SESSION_SEPARATOR);
    !session.is_empty()
        && has_only_session_characters
        && !starts_like_an_option
}

fn to_arguments(options: &[&str]) -> Vec<String> {
    options.iter().map(ToString::to_string).collect()
}

fn command_for(program: &str, arguments: Vec<String>) -> CommandSpecification {
    CommandSpecification {
        program: program.to_string(),
        arguments,
        environment: BTreeMap::new(),
        working_directory: None,
    }
}

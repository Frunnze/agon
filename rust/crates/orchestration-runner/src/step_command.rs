use orchestration_core::agent_kind_label::describe_agent_kind;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::SandboxKind;
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_command::{
    AgentCommandError, ClaudeControlCommand, PermissionAnswerer,
    build_agent_command, build_claude_control_command,
    choose_permission_answerer,
};
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::protected_files_settings::add_protected_files_settings;
use orchestration_hub::sandbox::{
    SandboxError, wrap_in_sandbox, wrap_in_sandbox_keeping_input_open,
};
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use thiserror::Error;

use crate::agent_sandbox::AgentSandbox;

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum StepCommandError {
    #[error(transparent)]
    Agent(#[from] AgentCommandError),
    #[error(transparent)]
    Sandbox(#[from] SandboxError),
    #[error(
        "{agent} can't be kept away from the files agents can't read when \
         it runs on this computer, so the run was refused: run the task in \
         Docker, or empty the list in Settings"
    )]
    FilesCannotBeProtected { agent: &'static str },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum StepCommand {
    PromptInArguments(CommandSpecification),
    PromptOnInput(ClaudeControlCommand),
}

pub fn build_step_command(
    sandbox: &AgentSandbox,
    mounts: &WorkspaceMounts,
    agent: AgentKind,
    approval_policy: ApprovalPolicy,
    protected_files: &ProtectedFiles,
    prompt: &str,
    session: Option<&str>,
) -> Result<StepCommand, StepCommandError> {
    ensure_files_stay_protected(agent, sandbox.kind, protected_files)?;

    match choose_permission_answerer(agent, approval_policy) {
        PermissionAnswerer::AgentFlags => {
            let agent_command =
                build_agent_command(agent, prompt, session, sandbox.kind)?;
            let protected_command =
                protect_agent_command(agent, &agent_command, protected_files);
            let command =
                wrap_closing_input(sandbox, mounts, protected_command)?;
            Ok(StepCommand::PromptInArguments(command))
        }
        PermissionAnswerer::Person => {
            let control = build_claude_control_command(prompt, session)?;
            let protected_command = add_protected_files_settings(
                &control.command,
                protected_files,
            );
            let command =
                wrap_keeping_input_open(sandbox, mounts, protected_command)?;
            Ok(StepCommand::PromptOnInput(ClaudeControlCommand {
                command,
                prompt_line: control.prompt_line,
            }))
        }
    }
}

fn ensure_files_stay_protected(
    agent: AgentKind,
    sandbox_kind: SandboxKind,
    protected_files: &ProtectedFiles,
) -> Result<(), StepCommandError> {
    let has_own_deny_list = agent == AgentKind::ClaudeCode;
    let runs_on_this_computer = sandbox_kind == SandboxKind::LocalProcess;
    let has_protected_files = !protected_files.patterns.is_empty();
    if !has_own_deny_list && runs_on_this_computer && has_protected_files {
        let agent = describe_agent_kind(agent);
        return Err(StepCommandError::FilesCannotBeProtected { agent });
    }
    Ok(())
}

fn protect_agent_command(
    agent: AgentKind,
    agent_command: &CommandSpecification,
    protected_files: &ProtectedFiles,
) -> CommandSpecification {
    if agent != AgentKind::ClaudeCode {
        return agent_command.clone();
    }
    add_protected_files_settings(agent_command, protected_files)
}

fn wrap_closing_input(
    sandbox: &AgentSandbox,
    mounts: &WorkspaceMounts,
    agent_command: CommandSpecification,
) -> Result<CommandSpecification, SandboxError> {
    wrap_in_sandbox(
        sandbox.kind,
        &sandbox.container,
        &with_sandbox_environment(sandbox, agent_command),
        mounts,
        &sandbox.allowed_hosts,
    )
}

fn wrap_keeping_input_open(
    sandbox: &AgentSandbox,
    mounts: &WorkspaceMounts,
    agent_command: CommandSpecification,
) -> Result<CommandSpecification, SandboxError> {
    wrap_in_sandbox_keeping_input_open(
        sandbox.kind,
        &sandbox.container,
        &with_sandbox_environment(sandbox, agent_command),
        mounts,
        &sandbox.allowed_hosts,
    )
}

fn with_sandbox_environment(
    sandbox: &AgentSandbox,
    agent_command: CommandSpecification,
) -> CommandSpecification {
    CommandSpecification {
        environment: sandbox.environment.clone(),
        ..agent_command
    }
}

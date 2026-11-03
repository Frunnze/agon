use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_command::{
    AgentCommandError, ClaudeControlCommand, PermissionAnswerer,
    build_agent_command, build_claude_control_command,
    choose_permission_answerer,
};
use orchestration_hub::command_specification::CommandSpecification;
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
    prompt: &str,
    session: Option<&str>,
) -> Result<StepCommand, StepCommandError> {
    match choose_permission_answerer(agent, approval_policy) {
        PermissionAnswerer::AgentFlags => {
            let agent_command =
                build_agent_command(agent, prompt, session, sandbox.kind)?;
            let command = wrap_closing_input(sandbox, mounts, agent_command)?;
            Ok(StepCommand::PromptInArguments(command))
        }
        PermissionAnswerer::Person => {
            let control = build_claude_control_command(prompt, session)?;
            let command =
                wrap_keeping_input_open(sandbox, mounts, control.command)?;
            Ok(StepCommand::PromptOnInput(ClaudeControlCommand {
                command,
                prompt_line: control.prompt_line,
            }))
        }
    }
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

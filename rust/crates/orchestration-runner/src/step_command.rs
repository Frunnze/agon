use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_command::{
    AgentCommandError, build_agent_command,
};
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::sandbox::{SandboxError, wrap_in_sandbox};
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

pub fn build_step_command(
    sandbox: &AgentSandbox,
    mounts: &WorkspaceMounts,
    agent: AgentKind,
    prompt: &str,
    session: Option<&str>,
) -> Result<CommandSpecification, StepCommandError> {
    let agent_command =
        build_agent_command(agent, prompt, session, sandbox.kind)?;
    let command_with_environment = CommandSpecification {
        environment: sandbox.environment.clone(),
        ..agent_command
    };

    let sandboxed_command = wrap_in_sandbox(
        sandbox.kind,
        &sandbox.container,
        &command_with_environment,
        mounts,
        &sandbox.allowed_hosts,
    )?;
    Ok(sandboxed_command)
}

use orchestration_core::device::SandboxKind;
use orchestration_runner::agent_sandbox::AgentSandbox;

use crate::agent_credentials::AgentCredential;
use crate::runner_settings::SandboxSettings;

#[must_use]
pub fn choose_container_credential(
    sandboxes: &[SandboxSettings],
    credential: Option<AgentCredential>,
) -> Option<AgentCredential> {
    let offers_container = sandboxes
        .iter()
        .any(|sandbox| matches!(sandbox, SandboxSettings::Container { .. }));
    if offers_container {
        return credential;
    }
    None
}

#[must_use]
pub fn pass_agent_credential(
    sandbox: &AgentSandbox,
    credential: Option<&AgentCredential>,
) -> AgentSandbox {
    let mut environment = sandbox.environment.clone();
    if let Some(credential) = credential
        && sandbox.kind == SandboxKind::Container
    {
        environment.insert(
            credential.environment_variable().to_owned(),
            credential.secret().to_owned(),
        );
    }
    AgentSandbox {
        environment,
        ..sandbox.clone()
    }
}

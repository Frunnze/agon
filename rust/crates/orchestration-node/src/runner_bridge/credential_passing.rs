use orchestration_runner::agent_sandbox::AgentSandbox;

use crate::agent_credentials::AgentCredential;
use crate::runner_settings::SandboxSettings;

#[must_use]
pub fn choose_container_credential(
    sandbox: &SandboxSettings,
    credential: Option<AgentCredential>,
) -> Option<AgentCredential> {
    match sandbox {
        SandboxSettings::Container { .. } => credential,
        SandboxSettings::LocalProcess => None,
    }
}

#[must_use]
pub fn pass_agent_credential(
    sandbox: &AgentSandbox,
    credential: Option<&AgentCredential>,
) -> AgentSandbox {
    let mut environment = sandbox.environment.clone();
    if let Some(credential) = credential {
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

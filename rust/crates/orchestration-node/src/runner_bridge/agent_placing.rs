use orchestration_core::agent_place::AgentPlace;

use crate::runner_settings::{RunnerSettings, SandboxSettings};

#[must_use]
pub fn offer_sandboxes(
    settings: &RunnerSettings,
    offers: &[AgentPlace],
    detected_container: &SandboxSettings,
) -> Vec<SandboxSettings> {
    let mut sandboxes = Vec::new();
    for offer in offers {
        let sandbox = match (offer, &settings.sandbox) {
            (AgentPlace::LocalProcess, _) => SandboxSettings::LocalProcess,
            (AgentPlace::Container, SandboxSettings::Container { .. }) => {
                settings.sandbox.clone()
            }
            (AgentPlace::Container, SandboxSettings::LocalProcess) => {
                detected_container.clone()
            }
        };
        sandboxes.push(sandbox);
    }
    sandboxes
}

#[must_use]
pub fn find_settings_place(sandbox: &SandboxSettings) -> AgentPlace {
    match sandbox {
        SandboxSettings::LocalProcess => AgentPlace::LocalProcess,
        SandboxSettings::Container { .. } => AgentPlace::Container,
    }
}

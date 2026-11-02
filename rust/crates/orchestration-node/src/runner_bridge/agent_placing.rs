use crate::runner_settings::{AgentPlace, RunnerSettings, SandboxSettings};

#[must_use]
pub fn place_agents(
    settings: &RunnerSettings,
    place: AgentPlace,
    detected_container: &SandboxSettings,
) -> RunnerSettings {
    let sandbox = match (place, &settings.sandbox) {
        (AgentPlace::LocalProcess, _) => SandboxSettings::LocalProcess,
        (AgentPlace::Container, SandboxSettings::Container { .. }) => {
            settings.sandbox.clone()
        }
        (AgentPlace::Container, SandboxSettings::LocalProcess) => {
            detected_container.clone()
        }
    };
    RunnerSettings {
        sandbox,
        ..settings.clone()
    }
}

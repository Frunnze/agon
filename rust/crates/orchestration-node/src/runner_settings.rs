use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ContainerEngineChoice {
    Docker,
    Podman,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentPlace {
    Container,
    LocalProcess,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum SandboxSettings {
    LocalProcess,
    Container {
        engine: ContainerEngineChoice,
        image: String,
        allowed_hosts: Vec<String>,
    },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RunnerSettings {
    pub labels: Vec<String>,
    pub slot_capacity: u32,
    pub sandbox: SandboxSettings,
    pub clone_url_template: Option<String>,
    #[serde(default)]
    pub passed_environment: Vec<String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RunnerOff {
    Off,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(untagged)]
pub enum RunnerChoice {
    Off(RunnerOff),
    Given(RunnerSettings),
}

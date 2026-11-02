use std::collections::BTreeMap;

use orchestration_core::device::SandboxKind;
use orchestration_hub::sandbox::ContainerSettings;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AgentSandbox {
    pub kind: SandboxKind,
    pub container: ContainerSettings,
    pub allowed_hosts: Vec<String>,
    pub environment: BTreeMap<String, String>,
}

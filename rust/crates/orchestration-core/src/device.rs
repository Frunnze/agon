use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::agent_place::AgentPlace;
use crate::identifiers::{DeviceId, WorkspaceId};
use crate::peer_address::SignedPeerAddress;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DeviceRole {
    Client,
    Runner,
    ClientAndRunner,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HardwareKeyKind {
    SecureEnclave,
    Tpm,
    StrongBox,
    Software,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Device {
    pub id: DeviceId,
    pub name: String,
    pub role: DeviceRole,
    pub key_kind: HardwareKeyKind,
    pub signing_public_key: Vec<u8>,
    pub sealing_public_key: Vec<u8>,
    pub workspaces: Vec<WorkspaceId>,
    pub paired_at: DateTime<Utc>,
    pub approved_by: Option<DeviceId>,
    pub last_seen: DateTime<Utc>,
    pub revoked: bool,
    pub peer_address: Option<SignedPeerAddress>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RunnerLink {
    Direct,
    Relay,
    LocalNetwork,
    Unreachable,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Runner {
    pub device_id: DeviceId,
    pub labels: Vec<String>,
    pub slots_total: u32,
    pub slots_busy: u32,
    pub link: RunnerLink,
    pub online: bool,
    pub accepting_new_runs: bool,
    #[serde(default)]
    pub offers: Vec<AgentPlace>,
    pub allowed_hosts: Vec<String>,
    #[serde(default)]
    pub cached_repositories: Vec<String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SandboxKind {
    Container,
    MicroVirtualMachine,
    LocalProcess,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum RunnerTarget {
    AnyFreeRunner,
    SpecificRunner { device_id: DeviceId },
    RunnerWithLabels { labels: Vec<String> },
}

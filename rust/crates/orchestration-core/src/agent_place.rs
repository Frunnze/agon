use serde::{Deserialize, Serialize};

use crate::device::SandboxKind;

#[derive(
    Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize,
)]
#[serde(rename_all = "snake_case")]
pub enum AgentPlace {
    LocalProcess,
    Container,
}

#[must_use]
pub fn can_take_place(
    offers: &[AgentPlace],
    wanted: Option<AgentPlace>,
) -> bool {
    match wanted {
        Some(place) => offers.contains(&place),
        None => !offers.is_empty(),
    }
}

#[must_use]
pub fn find_sandbox_place(kind: SandboxKind) -> Option<AgentPlace> {
    match kind {
        SandboxKind::LocalProcess => Some(AgentPlace::LocalProcess),
        SandboxKind::Container => Some(AgentPlace::Container),
        SandboxKind::MicroVirtualMachine => None,
    }
}

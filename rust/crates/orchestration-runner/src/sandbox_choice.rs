use orchestration_core::agent_place::{AgentPlace, find_sandbox_place};

use crate::agent_sandbox::AgentSandbox;

#[must_use]
pub fn choose_sandbox(
    sandboxes: &[AgentSandbox],
    wanted: Option<AgentPlace>,
) -> Option<&AgentSandbox> {
    let Some(wanted_place) = wanted else {
        return sandboxes.first();
    };
    sandboxes
        .iter()
        .find(|sandbox| find_sandbox_place(sandbox.kind) == Some(wanted_place))
}

use std::sync::Arc;
use std::time::Duration;

use orchestration_core::identifiers::RunId;

use crate::agent_sandbox::AgentSandbox;
use crate::run_workspace::RunWorkspace;

pub(crate) struct RunContext<S, P> {
    pub(crate) server: Arc<S>,
    pub(crate) pusher: Arc<P>,
    pub(crate) run_id: RunId,
    pub(crate) sandbox: AgentSandbox,
    pub(crate) workspace: RunWorkspace,
    pub(crate) cancellation_check_interval: Duration,
}

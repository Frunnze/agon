use std::sync::Arc;

use orchestration_api::work::{RunAssignment, RunEvent, RunEventsRequest};
use orchestration_core::identifiers::RunId;
use orchestration_node::runner_bridge::NodeRunnerServer;
use orchestration_runner::runner_server::RunnerServer;
use tokio::runtime::Runtime;

use super::drafting_desk::agent_message;
use super::runner_access::{claim_next_assignment, test_runtime};
use super::test_device::{TestDevice, describe, read_text};
use super::test_server::TestServer;

const WORKSPACE_NAME: &str = "acme";

#[derive(Debug)]
pub struct FirstProjectDesk {
    pub server: TestServer,
    pub device: TestDevice,
    pub workspace_id: String,
    runtime: Runtime,
    runner: Arc<NodeRunnerServer>,
}

pub fn open_first_project_desk() -> Result<FirstProjectDesk, String> {
    let server = TestServer::start()?;
    let device = TestDevice::start()?;
    let account = device.create_account(&server, WORKSPACE_NAME)?;
    let workspace_id = read_text(&account, "/workspaces/0/id")?;
    let runner = Arc::new(device.open_runner_server()?);
    Ok(FirstProjectDesk {
        server,
        device,
        workspace_id,
        runtime: test_runtime()?,
        runner,
    })
}

impl FirstProjectDesk {
    pub fn claim(&self) -> Result<RunAssignment, String> {
        claim_next_assignment(&self.runner, &self.runtime)
    }

    pub fn finish(
        &self,
        run_id: RunId,
        final_message: &str,
    ) -> Result<(), String> {
        let request = RunEventsRequest {
            events: vec![agent_message(final_message), RunEvent::Finished],
        };
        let posting = self.runner.post_run_events(run_id, &request);
        self.runtime.block_on(posting).map_err(describe)
    }
}

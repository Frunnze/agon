use orchestration_api::routes::{
    RUN_EVENTS, RUNNER_ACCEPTING, RUNNER_CLAIM, RUNNER_HEARTBEAT, RUNNERS,
};
use orchestration_api::work::{
    ClaimResponse, HeartbeatRequest, RunEventsRequest, SetAcceptingRunsRequest,
};
use orchestration_core::device::Runner;
use orchestration_core::identifiers::{DeviceId, RunId};
use reqwest::Method;

use super::decode_answer;
use super::route_paths::fill_route;
use super::signed_server_client::SignedServerClient;
use super::work_routes::fill_run_route;
use crate::node_error::NodeError;

const DEVICE_PLACEHOLDER: &str = "device_id";

impl SignedServerClient<'_> {
    pub async fn list_runners(&self) -> Result<Vec<Runner>, NodeError> {
        self.fetch(RUNNERS).await
    }

    pub async fn send_heartbeat(
        &self,
        request: &HeartbeatRequest,
    ) -> Result<(), NodeError> {
        self.submit(Method::POST, RUNNER_HEARTBEAT, request).await
    }

    pub async fn claim_run(&self) -> Result<ClaimResponse, NodeError> {
        let answer =
            self.submit_without_body(Method::POST, RUNNER_CLAIM).await?;
        decode_answer(&answer)
    }

    pub async fn send_run_events(
        &self,
        run_id: RunId,
        request: &RunEventsRequest,
    ) -> Result<(), NodeError> {
        let path = fill_run_route(RUN_EVENTS, run_id)?;
        self.submit(Method::POST, &path, request).await
    }

    pub async fn set_accepting_runs(
        &self,
        device_id: &DeviceId,
        request: &SetAcceptingRunsRequest,
    ) -> Result<(), NodeError> {
        let path = fill_route(
            RUNNER_ACCEPTING,
            &[(DEVICE_PLACEHOLDER, &device_id.0)],
        )?;
        self.submit(Method::PUT, &path, request).await
    }
}

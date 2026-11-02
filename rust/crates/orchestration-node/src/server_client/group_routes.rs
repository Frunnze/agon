use std::time::Duration;

use orchestration_api::routes::{
    SERVER_GROUP, SERVER_GROUP_MEMBER, SERVER_GROUP_MEMBERS,
    SERVER_GROUP_REPLICA,
};
use orchestration_api::server_group::{
    JoinServerGroupRequest, ServerGroupView,
};
use orchestration_core::identifiers::DeviceId;
use reqwest::Method;

use super::outgoing_request::OutgoingRequest;
use super::{SignedServerClient, decode_answer, fill_route};
use crate::node_error::NodeError;

const REPLICA_AFTER_PARAMETER: &str = "after";

impl SignedServerClient<'_> {
    pub async fn read_server_group(
        &self,
    ) -> Result<ServerGroupView, NodeError> {
        self.fetch(SERVER_GROUP).await
    }

    pub async fn join_server_group(
        &self,
        request: &JoinServerGroupRequest,
    ) -> Result<ServerGroupView, NodeError> {
        self.exchange(Method::PUT, SERVER_GROUP_MEMBERS, request)
            .await
    }

    pub async fn leave_server_group(
        &self,
        device_id: &DeviceId,
    ) -> Result<ServerGroupView, NodeError> {
        let path =
            fill_route(SERVER_GROUP_MEMBER, &[("device_id", &device_id.0)])?;
        let answer = self.submit_without_body(Method::DELETE, &path).await?;
        decode_answer(&answer)
    }

    pub async fn fetch_replica(
        &self,
        after_revision: u64,
        longest_wait: Duration,
    ) -> Result<Option<Vec<u8>>, NodeError> {
        let path = format!(
            "{SERVER_GROUP_REPLICA}?{REPLICA_AFTER_PARAMETER}={after_revision}"
        );
        let request = OutgoingRequest::without_body(Method::GET, &path)
            .waiting_up_to(longest_wait);
        let replica_bytes = self.send_request(request).await?;
        if replica_bytes.is_empty() {
            return Ok(None);
        }
        Ok(Some(replica_bytes))
    }
}

use std::time::Duration;

use orchestration_api::accounts::{
    AccountView, ApprovePairingRequest, CreateAccountRequest,
    PairingCommitment, PairingNonce, PairingRequestView,
    PairingSessionCreated, PublishPeerAddressRequest, RevokeDeviceRequest,
};
use orchestration_api::catalog::{
    AddWorkspaceDeviceRequest, CreateWorkspaceRequest,
};
use orchestration_api::routes::{
    ACCOUNTS, AUDIT, DEVICE_PEER_ADDRESS, DEVICE_REVOKE, DEVICES, EVENTS,
    PAIRING_APPROVE, PAIRING_APPROVER_NONCE, PAIRING_CANCEL,
    PAIRING_COMMITMENT, PAIRING_REJECT, PAIRING_SESSION, PAIRING_SESSIONS,
    WORKSPACE_DEVICE, WORKSPACE_DEVICES, WORKSPACES,
};
use orchestration_api::updates::{AuditView, EventsResponse};
use orchestration_core::device::Device;
use orchestration_core::identifiers::{DeviceId, WorkspaceId};
use orchestration_core::workspace::Workspace;
use reqwest::Method;

use super::decode_answer;
use super::outgoing_request::OutgoingRequest;
use super::route_paths::fill_route;
use super::signed_server_client::SignedServerClient;
use crate::node_error::NodeError;

const LONG_POLL_TIMEOUT: Duration = Duration::from_secs(90);
const EVENTS_AFTER_PARAMETER: &str = "after";

impl SignedServerClient<'_> {
    pub async fn create_account(
        &self,
        request: &CreateAccountRequest,
    ) -> Result<AccountView, NodeError> {
        self.exchange(Method::POST, ACCOUNTS, request).await
    }

    pub async fn read_account(&self) -> Result<AccountView, NodeError> {
        self.fetch(ACCOUNTS).await
    }

    pub async fn start_pairing_session(
        &self,
    ) -> Result<PairingSessionCreated, NodeError> {
        let answer = self
            .submit_without_body(Method::POST, PAIRING_SESSIONS)
            .await?;
        decode_answer(&answer)
    }

    pub async fn read_pairing_request(
        &self,
        code: &str,
    ) -> Result<PairingRequestView, NodeError> {
        let path = fill_route(PAIRING_SESSION, &[("code", code)])?;
        self.fetch(&path).await
    }

    pub async fn commit_pairing(
        &self,
        code: &str,
        commitment: &PairingCommitment,
    ) -> Result<(), NodeError> {
        let path = fill_route(PAIRING_COMMITMENT, &[("code", code)])?;
        self.submit(Method::POST, &path, commitment).await
    }

    pub async fn reveal_pairing_nonce(
        &self,
        code: &str,
        nonce: &PairingNonce,
    ) -> Result<(), NodeError> {
        let path = fill_route(PAIRING_APPROVER_NONCE, &[("code", code)])?;
        self.submit(Method::POST, &path, nonce).await
    }

    pub async fn approve_pairing(
        &self,
        code: &str,
        request: &ApprovePairingRequest,
    ) -> Result<(), NodeError> {
        let path = fill_route(PAIRING_APPROVE, &[("code", code)])?;
        self.submit(Method::POST, &path, request).await
    }

    pub async fn reject_pairing(&self, code: &str) -> Result<(), NodeError> {
        self.end_pairing_session(PAIRING_REJECT, code).await
    }

    pub async fn cancel_pairing(&self, code: &str) -> Result<(), NodeError> {
        self.end_pairing_session(PAIRING_CANCEL, code).await
    }

    pub async fn publish_peer_address(
        &self,
        request: &PublishPeerAddressRequest,
    ) -> Result<(), NodeError> {
        self.submit(Method::PUT, DEVICE_PEER_ADDRESS, request).await
    }

    pub async fn list_devices(&self) -> Result<Vec<Device>, NodeError> {
        self.fetch(DEVICES).await
    }

    pub async fn revoke_device(
        &self,
        device_id: &DeviceId,
        request: &RevokeDeviceRequest,
    ) -> Result<(), NodeError> {
        let path = fill_route(DEVICE_REVOKE, &[("device_id", &device_id.0)])?;
        self.submit(Method::POST, &path, request).await
    }

    pub async fn list_workspaces(&self) -> Result<Vec<Workspace>, NodeError> {
        self.fetch(WORKSPACES).await
    }

    pub async fn create_workspace(
        &self,
        request: &CreateWorkspaceRequest,
    ) -> Result<(), NodeError> {
        self.submit(Method::POST, WORKSPACES, request).await
    }

    pub async fn add_workspace_device(
        &self,
        workspace_id: WorkspaceId,
        request: &AddWorkspaceDeviceRequest,
    ) -> Result<(), NodeError> {
        let workspace_text = workspace_id.0.to_string();
        let path = fill_route(
            WORKSPACE_DEVICES,
            &[("workspace_id", &workspace_text)],
        )?;
        self.submit(Method::POST, &path, request).await
    }

    pub async fn remove_workspace_device(
        &self,
        workspace_id: WorkspaceId,
        device_id: &DeviceId,
    ) -> Result<(), NodeError> {
        let workspace_text = workspace_id.0.to_string();
        let path = fill_route(
            WORKSPACE_DEVICE,
            &[
                ("workspace_id", &workspace_text),
                ("device_id", &device_id.0),
            ],
        )?;
        self.submit_without_body(Method::DELETE, &path).await?;
        Ok(())
    }

    pub async fn read_audit(&self) -> Result<AuditView, NodeError> {
        self.fetch(AUDIT).await
    }

    pub async fn poll_events(
        &self,
        after_sequence: u64,
    ) -> Result<EventsResponse, NodeError> {
        let path =
            format!("{EVENTS}?{EVENTS_AFTER_PARAMETER}={after_sequence}");
        let request = OutgoingRequest::without_body(Method::GET, &path)
            .waiting_up_to(LONG_POLL_TIMEOUT);
        let answer = self.send_request(request).await?;
        decode_answer(&answer)
    }

    async fn end_pairing_session(
        &self,
        route: &str,
        code: &str,
    ) -> Result<(), NodeError> {
        let path = fill_route(route, &[("code", code)])?;
        self.submit_without_body(Method::POST, &path).await?;
        Ok(())
    }
}

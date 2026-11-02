use chrono::{DateTime, Utc};
use orchestration_core::device::{Device, DeviceRole, HardwareKeyKind};
use orchestration_core::identifiers::{DeviceId, WorkspaceId};
use orchestration_core::peer_address::SignedPeerAddress;
use orchestration_core::workspace::Workspace;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeviceRegistration {
    pub name: String,
    pub role: DeviceRole,
    pub key_kind: HardwareKeyKind,
    pub signing_public_key: Vec<u8>,
    pub sealing_public_key: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SealedWorkspaceKey {
    pub workspace_id: WorkspaceId,
    pub sealed_key: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CreateAccountRequest {
    pub device: DeviceRegistration,
    pub workspace_id: WorkspaceId,
    pub workspace_name: String,
    pub sealed_workspace_key: Vec<u8>,
    pub setup_code: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AccountView {
    pub device: Device,
    pub workspaces: Vec<Workspace>,
    pub sealed_workspace_keys: Vec<SealedWorkspaceKey>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PairingSessionCreated {
    pub code: String,
    pub started_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct JoinRequest {
    pub code: String,
    pub device: DeviceRegistration,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct JoinAccepted {
    pub join_id: Uuid,
    pub approver_signing_public_key: Vec<u8>,
    pub approver_sealing_public_key: Vec<u8>,
    pub approver_commitment: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PairingCommitment {
    pub commitment: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PairingNonce {
    pub nonce: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct JoiningDevice {
    pub name: String,
    pub role: DeviceRole,
    pub key_kind: HardwareKeyKind,
    pub signing_public_key: Vec<u8>,
    pub sealing_public_key: Vec<u8>,
    pub joiner_nonce: Option<Vec<u8>>,
    pub approver_nonce: Option<Vec<u8>>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PairingRequestView {
    pub code: String,
    pub started_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub joining: Option<JoiningDevice>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ApprovePairingRequest {
    pub sealed_workspace_keys: Vec<SealedWorkspaceKey>,
    pub approval_signature: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "state", rename_all = "snake_case")]
#[allow(clippy::large_enum_variant)]
pub enum JoinStatus {
    Waiting {
        approver_nonce: Option<Vec<u8>>,
    },
    Approved {
        account: AccountView,
        approver_nonce: Vec<u8>,
    },
    Rejected,
    Expired,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PublishPeerAddressRequest {
    pub address: SignedPeerAddress,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RevokeDeviceRequest {
    pub approval_signature: Vec<u8>,
}

const REVOCATION_STATEMENT_PREFIX: &str =
    "orchestration-device-revocation-v1:";

#[must_use]
pub fn revocation_statement(device_id: &DeviceId) -> Vec<u8> {
    format!("{REVOCATION_STATEMENT_PREFIX}{}", device_id.0).into_bytes()
}

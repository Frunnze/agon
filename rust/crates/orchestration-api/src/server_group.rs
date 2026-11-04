use chrono::{DateTime, Utc};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::{
    ServerGroup, ServerMember, ServerStanding,
};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReplicaCopy {
    pub device_id: DeviceId,
    pub verified_revision: u64,
    pub verified_at: DateTime<Utc>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ServerGroupView {
    pub group: ServerGroup,
    pub standing: ServerStanding,
    pub revision: u64,
    #[serde(default)]
    pub copies: Vec<ReplicaCopy>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct JoinServerGroupRequest {
    pub member: ServerMember,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReplicaQuery {
    pub after: u64,
}

use orchestration_core::server_group::{
    ServerGroup, ServerMember, ServerStanding,
};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ServerGroupView {
    pub group: ServerGroup,
    pub standing: ServerStanding,
    pub revision: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct JoinServerGroupRequest {
    pub member: ServerMember,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReplicaQuery {
    pub after: u64,
}

use chrono::{DateTime, Utc};
use orchestration_core::identifiers::{DeviceId, RunId};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AuditEntryView {
    pub index: u64,
    pub at: DateTime<Utc>,
    pub device_id: DeviceId,
    pub event: String,
    pub detail: Option<String>,
    pub previous_hash: String,
    pub hash: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AuditView {
    pub entries: Vec<AuditEntryView>,
    pub entry_count: u64,
    pub head_hash: String,
    pub intact: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "topic", rename_all = "snake_case")]
pub enum ChangeTopic {
    Account,
    Pairing,
    Devices,
    Workspaces,
    Projects,
    Workflows,
    Skills,
    Rules,
    Tasks,
    Run { run_id: RunId },
    Runners,
    Approvals,
    Audit,
    ServerGroup,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ChangeNotification {
    pub sequence: u64,
    pub topic: ChangeTopic,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct EventsResponse {
    pub notifications: Vec<ChangeNotification>,
    pub latest_sequence: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ApiErrorBody {
    pub message: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct EventsQuery {
    pub after: u64,
}

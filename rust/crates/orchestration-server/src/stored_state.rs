use std::collections::BTreeMap;

use chrono::{DateTime, Utc};
use orchestration_api::accounts::{DeviceRegistration, SealedWorkspaceKey};
use orchestration_api::updates::ChangeNotification;
use orchestration_core::approval::ApprovalRequest;
use orchestration_core::device::{Device, Runner};
use orchestration_core::identifiers::{
    ApprovalId, DeviceId, ProjectId, RuleId, RunId, SkillId, TaskId,
    WorkflowId, WorkspaceId,
};
use orchestration_core::library::{Rule, Skill};
use orchestration_core::run::Run;
use orchestration_core::server_group::ServerGroup;
use orchestration_core::task::Task;
use orchestration_core::workflow::Workflow;
use orchestration_core::workspace::{Project, Workspace};
use orchestration_security::audit::AuditEntry;
use orchestration_security::pairing::PairingSession;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct StoredState {
    pub devices: BTreeMap<DeviceId, Device>,
    pub workspace_keys: BTreeMap<DeviceId, Vec<SealedWorkspaceKey>>,
    pub workspaces: BTreeMap<WorkspaceId, Workspace>,
    pub pairing_sessions: BTreeMap<String, PairingRecord>,
    pub joins: BTreeMap<Uuid, JoinRecord>,
    pub projects: BTreeMap<ProjectId, Project>,
    pub workflows: BTreeMap<WorkflowId, WorkflowRecord>,
    pub skills: BTreeMap<SkillId, Skill>,
    pub rules: BTreeMap<RuleId, Rule>,
    pub tasks: BTreeMap<TaskId, Task>,
    pub runs: BTreeMap<RunId, RunRecord>,
    pub runners: BTreeMap<DeviceId, Runner>,
    pub approvals: BTreeMap<ApprovalId, ApprovalRequest>,
    pub job_marks: BTreeMap<TaskId, DateTime<Utc>>,
    pub audit_log: Vec<AuditEntry>,
    pub notifications: Vec<ChangeNotification>,
    pub latest_sequence: u64,
    #[serde(default)]
    pub server_group: ServerGroup,
    #[serde(default)]
    pub revision: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PairingRecord {
    pub session: PairingSession,
    pub started_by: DeviceId,
    pub join_id: Option<Uuid>,
    #[serde(default)]
    pub approver_commitment: Option<Vec<u8>>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct JoinRecord {
    pub session: PairingSession,
    pub registration: DeviceRegistration,
    #[serde(default)]
    pub joiner_nonce: Option<Vec<u8>>,
    #[serde(default)]
    pub approver_nonce: Option<Vec<u8>>,
    pub outcome: JoinOutcome,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "state", rename_all = "snake_case")]
pub enum JoinOutcome {
    Waiting,
    Approved { device_id: DeviceId },
    Rejected,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct WorkflowRecord {
    pub current: Workflow,
    pub last_signed: Option<Workflow>,
    #[serde(default)]
    pub signed_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub changed_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub changed_by: Option<DeviceId>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RunRecord {
    pub run: Run,
    pub pinned_steps: BTreeMap<String, DeviceId>,
}

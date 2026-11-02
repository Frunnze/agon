use chrono::{DateTime, Utc};
use orchestration_core::identifiers::{DeviceId, WorkspaceId};
use orchestration_core::library::{Rule, Skill};
use orchestration_core::workflow::{Workflow, WorkflowSignature};
use orchestration_core::workspace::{Project, Repository};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CreateWorkspaceRequest {
    pub workspace_id: WorkspaceId,
    pub name: String,
    pub sealed_workspace_key: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AddWorkspaceDeviceRequest {
    pub device_id: DeviceId,
    pub sealed_workspace_key: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SaveProjectRequest {
    pub project: Project,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AddRepositoryRequest {
    pub repository: Repository,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoveRepositoryRequest {
    pub address: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct WorkflowListing {
    pub workflow: Workflow,
    pub signed_at: Option<DateTime<Utc>>,
    pub changed_at: Option<DateTime<Utc>>,
    pub changed_by: Option<DeviceId>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SaveWorkflowRequest {
    pub workflow: Workflow,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SignWorkflowRequest {
    pub signature: WorkflowSignature,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SaveSkillRequest {
    pub skill: Skill,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SaveRuleRequest {
    pub rule: Rule,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SetRuleEnabledRequest {
    pub enabled: bool,
}

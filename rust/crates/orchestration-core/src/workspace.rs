use serde::{Deserialize, Serialize};

use crate::approval::ApprovalPolicy;
use crate::identifiers::{ProjectId, WorkspaceId};
use crate::protected_files::ProtectedFiles;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Workspace {
    pub id: WorkspaceId,
    pub name: String,
    pub app_server_address: String,
    #[serde(default)]
    pub approval_policy: ApprovalPolicy,
    #[serde(default)]
    pub protected_files: ProtectedFiles,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentAccess {
    ReadOnly,
    PushAfterApproval,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Repository {
    pub address: String,
    pub default_branch: String,
    pub agent_access: AgentAccess,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Project {
    pub id: ProjectId,
    pub workspace_id: WorkspaceId,
    pub name: String,
    pub repositories: Vec<Repository>,
    #[serde(default)]
    pub approval_policy: Option<ApprovalPolicy>,
}

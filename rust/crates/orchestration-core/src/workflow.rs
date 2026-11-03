use serde::{Deserialize, Serialize};

use crate::approval::ApprovalPolicy;
use crate::device::RunnerTarget;
use crate::identifiers::{DeviceId, SkillId, WorkflowAgentId, WorkflowId};
use crate::scope::WorkspaceScope;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentKind {
    ClaudeCode,
    Codex,
    GeminiCli,
}

#[derive(
    Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize,
)]
#[serde(rename_all = "snake_case")]
pub enum StepKind {
    #[default]
    Agent,
    Person,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct CanvasPosition {
    pub horizontal: f64,
    pub vertical: f64,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct WorkflowAgent {
    pub id: WorkflowAgentId,
    pub name: String,
    #[serde(default)]
    pub step_kind: StepKind,
    pub kind: Option<AgentKind>,
    pub task: String,
    pub runs_on: RunnerTarget,
    pub skills: Vec<SkillId>,
    pub uses_automatic_skills: bool,
    pub approval_policy: ApprovalPolicy,
    pub position: CanvasPosition,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentConnection {
    pub from: WorkflowAgentId,
    pub to: WorkflowAgentId,
    #[serde(default)]
    pub condition: Option<String>,
    #[serde(default)]
    pub round_limit: Option<u32>,
}

impl AgentConnection {
    #[must_use]
    pub fn plain(from: WorkflowAgentId, to: WorkflowAgentId) -> Self {
        Self {
            from,
            to,
            condition: None,
            round_limit: None,
        }
    }

    #[must_use]
    pub fn is_loop(&self) -> bool {
        self.round_limit.is_some()
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct WorkflowSignature {
    pub signed_by: DeviceId,
    pub signature: Vec<u8>,
    pub signed_document: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Workflow {
    pub id: WorkflowId,
    pub name: String,
    pub availability: WorkspaceScope,
    pub agents: Vec<WorkflowAgent>,
    pub connections: Vec<AgentConnection>,
    pub signature: Option<WorkflowSignature>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SignatureState {
    Signed,
    NotSignedYet,
    ChangedNotSigned,
}

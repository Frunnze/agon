use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::identifiers::{ApprovalId, DeviceId, RunId, SkillId, WorkflowId};

pub const UNLABELLED_COMMAND_SUMMARY: &str = "Use a tool";

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ApprovalAction {
    PushCommits {
        repository: String,
        branch: String,
        commits: Vec<String>,
    },
    Deploy {
        target: String,
    },
    DeleteBranchOrFiles {
        repository: String,
        what: String,
    },
    SignWorkflow {
        workflow_id: WorkflowId,
    },
    RunCommand {
        tool: String,
        #[serde(default = "name_unlabelled_command")]
        summary: String,
        command: String,
    },
    ImproveSkill {
        skill_id: SkillId,
        summary: String,
        proposed_instructions: String,
    },
}

fn name_unlabelled_command() -> String {
    UNLABELLED_COMMAND_SUMMARY.to_owned()
}

#[derive(
    Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize,
)]
#[serde(rename_all = "snake_case")]
pub enum ApprovalPolicy {
    AskBeforeRiskyActions,
    #[default]
    NeverAsk,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ApprovalDecision {
    Approved,
    Denied,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SignedDecision {
    pub decision: ApprovalDecision,
    pub decided_by: DeviceId,
    pub decided_at: DateTime<Utc>,
    pub signature: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ApprovalRequest {
    pub id: ApprovalId,
    pub run_id: Option<RunId>,
    pub action: ApprovalAction,
    pub requested_by: DeviceId,
    pub requested_at: DateTime<Utc>,
    pub decision: Option<SignedDecision>,
}

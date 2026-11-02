use chrono::{DateTime, Utc, Weekday};
use serde::{Deserialize, Serialize};

use crate::approval::ApprovalPolicy;
use crate::device::RunnerTarget;
use crate::identifiers::{
    ProjectId, SkillId, TaskId, WorkflowId, WorkspaceId,
};
use crate::workflow::AgentKind;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum TaskDoer {
    OneAgent { agent: AgentKind },
    Workflow { workflow_id: WorkflowId },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TimeOfDay {
    pub hour: u32,
    pub minute: u32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "every", rename_all = "snake_case")]
pub enum Schedule {
    Hour { minute: u32 },
    Day { at: TimeOfDay },
    Week { on: Weekday, at: TimeOfDay },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskStatus {
    ToDo,
    Running,
    WaitingForApproval,
    Failed,
    Done,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum TaskPlace {
    InProject { project_id: ProjectId },
    InWorkspace { workspace_id: WorkspaceId },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Task {
    pub id: TaskId,
    pub title: String,
    pub details: String,
    #[serde(flatten)]
    pub place: TaskPlace,
    pub doer: TaskDoer,
    pub runs_on: RunnerTarget,
    pub skills: Vec<SkillId>,
    pub uses_automatic_skills: bool,
    pub approval_policy: ApprovalPolicy,
    pub schedule: Option<Schedule>,
    pub status: TaskStatus,
    pub created_at: DateTime<Utc>,
}

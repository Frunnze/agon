use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::device::RunnerLink;
use crate::identifiers::{DeviceId, RunId, TaskId, WorkflowAgentId};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StepStatus {
    Waiting,
    Running,
    WaitingForApproval,
    WaitingForPerson,
    Done,
    Failed,
    Skipped,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RunStep {
    pub name: String,
    pub agent_id: Option<WorkflowAgentId>,
    pub runner: Option<DeviceId>,
    pub status: StepStatus,
    pub started_at: Option<DateTime<Utc>>,
    pub finished_at: Option<DateTime<Utc>>,
    pub result: Option<String>,
    #[serde(default)]
    pub outcome: Option<String>,
    #[serde(default)]
    pub loop_source: Option<String>,
    #[serde(default)]
    pub earlier_rounds: Vec<EarlierStepRound>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct EarlierStepRound {
    pub status: StepStatus,
    pub started_at: Option<DateTime<Utc>>,
    pub finished_at: Option<DateTime<Utc>>,
    pub result: Option<String>,
    pub outcome: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LoopRounds {
    pub from: String,
    pub to: String,
    pub rounds: u32,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RunNote {
    pub at: DateTime<Utc>,
    pub text: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RunStatus {
    Queued,
    Running,
    WaitingForApproval,
    Failed,
    Cancelled,
    Done,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LogLine {
    pub at: DateTime<Utc>,
    pub step_name: String,
    pub text: String,
    pub is_error: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ChatAuthor {
    You,
    Agent,
    Tool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ChatMessage {
    pub at: DateTime<Utc>,
    pub author: ChatAuthor,
    pub text: String,
    pub is_error: bool,
    pub waiting_to_send: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RunFailure {
    pub step_name: String,
    pub runner: Option<DeviceId>,
    pub reason: String,
    pub retry_runs_on_same_runner: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Run {
    pub id: RunId,
    pub task_id: TaskId,
    pub number: u32,
    pub status: RunStatus,
    pub steps: Vec<RunStep>,
    pub log: Vec<LogLine>,
    pub chat: Vec<ChatMessage>,
    pub failure: Option<RunFailure>,
    pub link: RunnerLink,
    pub link_lost_at: Option<DateTime<Utc>>,
    pub agent_session: Option<String>,
    pub worktree_branch: Option<String>,
    pub started_by: DeviceId,
    pub started_at: DateTime<Utc>,
    pub finished_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub loop_rounds: Vec<LoopRounds>,
    #[serde(default)]
    pub notes: Vec<RunNote>,
}

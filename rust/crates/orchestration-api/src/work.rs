use orchestration_core::approval::{ApprovalAction, SignedDecision};
use orchestration_core::device::{RunnerLink, SandboxKind};
use orchestration_core::identifiers::{RunId, WorkspaceId};
use orchestration_core::library::{Rule, Skill};
use orchestration_core::run::{
    ChatMessage, LogLine, Run, RunFailure, StepStatus,
};
use orchestration_core::task::Task;
use orchestration_core::workflow::Workflow;
use orchestration_core::workspace::Project;
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskStart {
    Now,
    Later,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SaveTaskRequest {
    pub task: Task,
    pub start: TaskStart,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct UpdateTaskRequest {
    pub task: Task,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SendChatMessageRequest {
    pub message: ChatMessage,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum RunEvent {
    StepStatusChanged {
        step_name: String,
        status: StepStatus,
    },
    LogAppended {
        line: LogLine,
    },
    ChatAppended {
        message: ChatMessage,
    },
    SessionStarted {
        session: String,
    },
    WorktreeCreated {
        branch: String,
    },
    LinkChanged {
        link: RunnerLink,
    },
    Failed {
        failure: RunFailure,
    },
    StepResultRecorded {
        step_name: String,
        result: String,
    },
    Finished,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RunEventsRequest {
    pub events: Vec<RunEvent>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct HeartbeatRequest {
    pub labels: Vec<String>,
    pub slots_total: u32,
    pub slots_busy: u32,
    pub link: RunnerLink,
    pub sandbox: SandboxKind,
    pub allowed_hosts: Vec<String>,
    #[serde(default)]
    pub cached_repositories: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RunAssignment {
    pub step_name: String,
    pub run: Run,
    pub task: Task,
    pub workspace_id: WorkspaceId,
    pub project: Option<Project>,
    pub workflow: Option<Workflow>,
    pub skills: Vec<Skill>,
    pub rules: Vec<Rule>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ClaimResponse {
    pub assignment: Option<RunAssignment>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SetAcceptingRunsRequest {
    pub accepting_new_runs: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CreateApprovalRequest {
    pub run_id: Option<RunId>,
    pub action: ApprovalAction,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct DecideApprovalRequest {
    pub decision: SignedDecision,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TaskSaved {
    pub task: Task,
    pub run: Option<Run>,
}

use std::collections::BTreeMap;

use chrono::{DateTime, Utc};
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::{RunnerLink, RunnerTarget};
use orchestration_core::identifiers::{
    DeviceId, ProjectId, RuleId, RunId, SkillId, TaskId, WorkflowAgentId,
    WorkflowId, WorkspaceId,
};
use orchestration_core::library::{Rule, Skill, SkillSource, SkillUsage};
use orchestration_core::run::{
    ChatAuthor, ChatMessage, LogLine, Run, RunStatus, RunStep, StepStatus,
};
use orchestration_core::scope::{Scope, WorkspaceScope};
use orchestration_core::task::{Task, TaskDoer, TaskPlace, TaskStatus};
use orchestration_core::workflow::{
    AgentKind, CanvasPosition, Workflow, WorkflowAgent,
};
use orchestration_node::content_sealing::WorkspaceKeyring;
use orchestration_security::sealing::WorkspaceKey;
use proptest::prelude::*;
use uuid::Uuid;

pub const SECRET_TEXT_PATTERN: &str = "secret[g-z]{12,24}";
const SAMPLE_TIME_SECONDS: i64 = 1_790_000_000;
const MAXIMUM_SECRET_COUNT: usize = 4;

pub fn secret_text_strategy() -> impl Strategy<Value = String> {
    SECRET_TEXT_PATTERN
}

pub fn secret_texts_strategy() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::vec(secret_text_strategy(), 1..MAXIMUM_SECRET_COUNT)
}

pub fn sample_time() -> DateTime<Utc> {
    DateTime::from_timestamp(SAMPLE_TIME_SECONDS, 0).unwrap_or_default()
}

pub fn sample_keyring(
    workspace_id: WorkspaceId,
) -> Result<(WorkspaceKey, WorkspaceKeyring), String> {
    let workspace_key =
        WorkspaceKey::generate().map_err(|error| error.to_string())?;
    let key_copy = WorkspaceKey::from_bytes(workspace_key.to_bytes().as_ref())
        .map_err(|error| error.to_string())?;
    let keyring = WorkspaceKeyring::from_keys(BTreeMap::from([(
        workspace_id,
        key_copy,
    )]));
    Ok((workspace_key, keyring))
}

pub fn sample_task(details: &str) -> Task {
    Task {
        id: TaskId(Uuid::from_u128(1)),
        title: "Ship release".to_owned(),
        details: details.to_owned(),
        place: TaskPlace::InProject {
            project_id: ProjectId(Uuid::from_u128(2)),
        },
        doer: TaskDoer::OneAgent {
            agent: AgentKind::ClaudeCode,
        },
        runs_on: RunnerTarget::AnyFreeRunner,
        skills: Vec::new(),
        uses_automatic_skills: true,
        approval_policy: ApprovalPolicy::AskBeforeRiskyActions,
        schedule: None,
        status: TaskStatus::ToDo,
        created_at: sample_time(),
    }
}

pub fn sample_workflow(agent_tasks: &[String]) -> Workflow {
    let mut agents = Vec::new();
    for (position, agent_task) in agent_tasks.iter().enumerate() {
        let agent_number = u128::try_from(position).unwrap_or_default();
        agents.push(WorkflowAgent {
            id: WorkflowAgentId(Uuid::from_u128(agent_number + 1)),
            name: format!("step-{position}"),
            kind: Some(AgentKind::Codex),
            task: agent_task.clone(),
            runs_on: RunnerTarget::AnyFreeRunner,
            skills: Vec::new(),
            uses_automatic_skills: false,
            approval_policy: ApprovalPolicy::NeverAsk,
            position: CanvasPosition {
                horizontal: f64::from(u8::try_from(position).unwrap_or(0)),
                vertical: 0.0,
            },
        });
    }
    Workflow {
        id: WorkflowId(Uuid::from_u128(3)),
        name: "release".to_owned(),
        availability: WorkspaceScope::AllWorkspaces,
        agents,
        connections: Vec::new(),
        signature: None,
    }
}

pub fn sample_skill(instructions: &str) -> Skill {
    Skill {
        id: SkillId(Uuid::from_u128(4)),
        name: "ios-release".to_owned(),
        summary: "Build the app".to_owned(),
        instructions: instructions.to_owned(),
        scope: Scope::everywhere(),
        usage: SkillUsage::Automatic,
        source: SkillSource::Created,
    }
}

pub fn sample_rule(details: &str) -> Rule {
    Rule {
        id: RuleId(Uuid::from_u128(5)),
        title: "Never push to main".to_owned(),
        details: details.to_owned(),
        scope: Scope::everywhere(),
        enabled: true,
        added_at: sample_time(),
    }
}

pub fn sample_chat_message(text: &str) -> ChatMessage {
    ChatMessage {
        at: sample_time(),
        author: ChatAuthor::You,
        text: text.to_owned(),
        is_error: false,
        waiting_to_send: false,
    }
}

pub fn sample_log_line(text: &str) -> LogLine {
    LogLine {
        at: sample_time(),
        step_name: "build".to_owned(),
        text: text.to_owned(),
        is_error: false,
    }
}

pub fn sample_step_with_result(position: usize, result: &str) -> RunStep {
    RunStep {
        name: format!("step-{position}"),
        agent_id: None,
        runner: None,
        status: StepStatus::Done,
        started_at: None,
        finished_at: None,
        result: Some(result.to_owned()),
    }
}

pub fn sample_run(texts: &[String]) -> Run {
    Run {
        id: RunId(Uuid::from_u128(6)),
        task_id: TaskId(Uuid::from_u128(1)),
        number: 1,
        status: RunStatus::Running,
        steps: Vec::new(),
        log: texts.iter().map(|text| sample_log_line(text)).collect(),
        chat: texts.iter().map(|text| sample_chat_message(text)).collect(),
        failure: None,
        link: RunnerLink::Direct,
        link_lost_at: None,
        agent_session: None,
        worktree_branch: None,
        started_by: DeviceId("device".to_owned()),
        started_at: sample_time(),
        finished_at: None,
    }
}

use chrono::DateTime;
use orchestration_api::work::RunAssignment;
use orchestration_core::agent_place::AgentPlace;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{
    DeviceId, ProjectId, RuleId, RunId, TaskId, WorkspaceId,
};
use orchestration_core::library::Rule;
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::run_lifecycle::create_run;
use orchestration_core::scope::Scope;
use orchestration_core::task::{Task, TaskDoer, TaskPlace, TaskStatus};
use orchestration_core::workflow::{AgentKind, Workflow};
use orchestration_core::workspace::{Project, Repository};
use proptest::prelude::*;
use uuid::Uuid;

use crate::support::TestResult;

pub const WORKSPACE_NUMBER: u128 = 0xa0a0;
pub const PROJECT_NUMBER: u128 = 0xb0b0;
const FIRST_RUN_NUMBER: u32 = 1;
const STARTING_DEVICE: &str = "laptop";

pub fn task_for(number: u128, title: &str, doer: TaskDoer) -> Task {
    Task {
        id: TaskId(Uuid::from_u128(number)),
        title: title.to_string(),
        details: String::new(),
        place: TaskPlace::InProject {
            project_id: ProjectId(Uuid::from_u128(PROJECT_NUMBER)),
        },
        doer,
        runs_on: RunnerTarget::AnyFreeRunner,
        agent_place: Some(AgentPlace::LocalProcess),
        skills: Vec::new(),
        uses_automatic_skills: false,
        approval_policy: Some(ApprovalPolicy::AskBeforeRiskyActions),
        schedule: None,
        status: TaskStatus::ToDo,
        created_at: DateTime::UNIX_EPOCH,
    }
}

pub fn claude_task(number: u128, title: &str) -> Task {
    let doer = TaskDoer::OneAgent {
        agent: AgentKind::ClaudeCode,
    };
    task_for(number, title, doer)
}

pub fn assignment_for(
    task: Task,
    workflow: Option<Workflow>,
    repositories: Vec<Repository>,
    run_number: u128,
) -> TestResult<RunAssignment> {
    let run = create_run(
        &task,
        workflow.as_ref(),
        FIRST_RUN_NUMBER,
        RunId(Uuid::from_u128(run_number)),
        DeviceId(STARTING_DEVICE.to_string()),
        DateTime::UNIX_EPOCH,
    )?;
    let workspace_id = WorkspaceId(Uuid::from_u128(WORKSPACE_NUMBER));
    let project = Project {
        id: ProjectId(Uuid::from_u128(PROJECT_NUMBER)),
        workspace_id,
        name: "app".to_string(),
        repositories,
        approval_policy: None,
    };
    let step_name = run.steps.first().map(|step| step.name.clone());
    Ok(RunAssignment {
        step_name: step_name.unwrap_or_default(),
        run,
        task,
        workspace_id,
        workspace_approval_policy: ApprovalPolicy::default(),
        project: Some(project),
        workflow,
        skills: Vec::new(),
        rules: Vec::new(),
        follow_up: None,
        protected_files: ProtectedFiles {
            patterns: Vec::new(),
        },
    })
}

pub fn workspace_assignment_for(
    task: Task,
    run_number: u128,
) -> TestResult<RunAssignment> {
    let workspace_id = WorkspaceId(Uuid::from_u128(WORKSPACE_NUMBER));
    let placed_task = Task {
        place: TaskPlace::InWorkspace { workspace_id },
        ..task
    };
    let project_assignment =
        assignment_for(placed_task, None, Vec::new(), run_number)?;
    Ok(RunAssignment {
        project: None,
        ..project_assignment
    })
}

pub fn any_agent_kind() -> impl Strategy<Value = AgentKind> {
    prop_oneof![
        Just(AgentKind::ClaudeCode),
        Just(AgentKind::Codex),
        Just(AgentKind::GeminiCli),
    ]
}

pub fn rule_titled(number: u128, title: &str, enabled: bool) -> Rule {
    Rule {
        id: RuleId(Uuid::from_u128(number)),
        title: title.to_string(),
        details: "Ask first.".to_string(),
        scope: Scope::everywhere(),
        enabled,
        added_at: DateTime::UNIX_EPOCH,
    }
}

pub fn claude_assignment(
    number: u128,
    title: &str,
) -> TestResult<RunAssignment> {
    assignment_for(claude_task(number, title), None, Vec::new(), number)
}

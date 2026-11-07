use chrono::{DateTime, Utc};
use thiserror::Error;

use crate::agent_kind_label::label_agent_kind;
use crate::device::RunnerLink;
use crate::identifiers::{DeviceId, RunId, WorkflowAgentId, WorkflowId};
use crate::run::{Run, RunStatus, RunStep, StepStatus};
use crate::task::{Task, TaskDoer};
use crate::workflow::{AgentKind, Workflow};
use crate::workflow_graph::{
    WorkflowProblem, agents_in_order, validate_workflow,
};

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum RunProblem {
    #[error(
        "the task runs workflow {} but no workflow was given",
        .workflow_id.0
    )]
    MissingWorkflow { workflow_id: WorkflowId },
    #[error(
        "the task runs workflow {} but workflow {} was given",
        .expected.0,
        .given.0
    )]
    WrongWorkflow {
        expected: WorkflowId,
        given: WorkflowId,
    },
    #[error("the task runs one agent, so it takes no workflow")]
    UnexpectedWorkflow,
    #[error(transparent)]
    InvalidWorkflow(#[from] WorkflowProblem),
    #[error("the run has no step named {step_name}")]
    UnknownStep { step_name: String },
    #[error("the run has already finished")]
    RunAlreadyFinished,
    #[error(
        "step {step_name} must end with one of the outcomes: {}",
        .choices.join(", ")
    )]
    UnknownOutcome {
        step_name: String,
        choices: Vec<String>,
    },
}

pub fn create_run(
    task: &Task,
    workflow: Option<&Workflow>,
    number: u32,
    run_id: RunId,
    started_by: DeviceId,
    started_at: DateTime<Utc>,
) -> Result<Run, RunProblem> {
    let steps = plan_steps(&task.doer, workflow)?;
    Ok(Run {
        id: run_id,
        task_id: task.id,
        number,
        status: RunStatus::Queued,
        steps,
        log: Vec::new(),
        chat: Vec::new(),
        failure: None,
        link: RunnerLink::Unreachable,
        link_lost_at: None,
        agent_session: None,
        worktree_branch: None,
        started_by,
        started_at,
        finished_at: None,
        loop_rounds: Vec::new(),
        notes: Vec::new(),
    })
}

pub fn apply_step_status(
    run: &Run,
    step_name: &str,
    status: StepStatus,
    at: DateTime<Utc>,
) -> Result<Run, RunProblem> {
    if is_run_finished(run.status) {
        return Err(RunProblem::RunAlreadyFinished);
    }
    let is_known_step = run.steps.iter().any(|step| step.name == step_name);
    if !is_known_step {
        return Err(RunProblem::UnknownStep {
            step_name: step_name.to_owned(),
        });
    }

    let changed_steps: Vec<RunStep> = run
        .steps
        .iter()
        .map(|step| {
            if step.name == step_name {
                change_step_status(step, status, at)
            } else {
                step.clone()
            }
        })
        .collect();
    let run_status = derive_run_status(&changed_steps);
    let settled_steps = if run_status == RunStatus::Failed {
        skip_unfinished_steps(&changed_steps, at)
    } else {
        changed_steps
    };
    let finished_at = is_run_finished(run_status).then_some(at);

    Ok(Run {
        status: run_status,
        steps: settled_steps,
        finished_at,
        ..run.clone()
    })
}

#[must_use]
pub fn derive_run_status(steps: &[RunStep]) -> RunStatus {
    let all_waiting =
        steps.iter().all(|step| step.status == StepStatus::Waiting);
    let all_finished = steps.iter().all(|step| {
        matches!(step.status, StepStatus::Done | StepStatus::Skipped)
    });

    if has_step_with_status(steps, StepStatus::Failed) {
        return RunStatus::Failed;
    }
    if has_step_with_status(steps, StepStatus::WaitingForApproval) {
        return RunStatus::WaitingForApproval;
    }
    if all_waiting {
        return RunStatus::Queued;
    }
    if all_finished {
        return RunStatus::Done;
    }
    RunStatus::Running
}

fn plan_steps(
    doer: &TaskDoer,
    workflow: Option<&Workflow>,
) -> Result<Vec<RunStep>, RunProblem> {
    match (doer, workflow) {
        (TaskDoer::OneAgent { agent }, None) => {
            Ok(vec![plan_single_agent_step(*agent)])
        }
        (TaskDoer::OneAgent { .. }, Some(_)) => {
            Err(RunProblem::UnexpectedWorkflow)
        }
        (TaskDoer::Workflow { workflow_id }, None) => {
            Err(RunProblem::MissingWorkflow {
                workflow_id: *workflow_id,
            })
        }
        (TaskDoer::Workflow { workflow_id }, Some(workflow)) => {
            plan_workflow_steps(*workflow_id, workflow)
        }
    }
}

fn plan_single_agent_step(agent: AgentKind) -> RunStep {
    waiting_step(label_agent_kind(agent).to_owned(), None)
}

fn plan_workflow_steps(
    expected_id: WorkflowId,
    workflow: &Workflow,
) -> Result<Vec<RunStep>, RunProblem> {
    if workflow.id != expected_id {
        return Err(RunProblem::WrongWorkflow {
            expected: expected_id,
            given: workflow.id,
        });
    }
    validate_workflow(workflow)?;
    let steps = agents_in_order(workflow)
        .iter()
        .map(|agent| waiting_step(agent.name.clone(), Some(agent.id)))
        .collect();
    Ok(steps)
}

fn waiting_step(name: String, agent_id: Option<WorkflowAgentId>) -> RunStep {
    RunStep {
        name,
        agent_id,
        runner: None,
        status: StepStatus::Waiting,
        started_at: None,
        finished_at: None,
        result: None,
        outcome: None,
        loop_source: None,
        earlier_rounds: Vec::new(),
    }
}

fn change_step_status(
    step: &RunStep,
    status: StepStatus,
    at: DateTime<Utc>,
) -> RunStep {
    let is_starting =
        status == StepStatus::Running && step.started_at.is_none();
    let started_at = if is_starting {
        Some(at)
    } else {
        step.started_at
    };
    let finished_at = is_step_finished(status).then_some(at);
    RunStep {
        status,
        started_at,
        finished_at,
        ..step.clone()
    }
}

#[must_use]
pub fn skip_unfinished_steps(
    steps: &[RunStep],
    at: DateTime<Utc>,
) -> Vec<RunStep> {
    let mut settled_steps = Vec::new();
    for step in steps {
        if is_step_finished(step.status) {
            settled_steps.push(step.clone());
            continue;
        }
        settled_steps.push(RunStep {
            status: StepStatus::Skipped,
            finished_at: Some(at),
            ..step.clone()
        });
    }
    settled_steps
}

fn has_step_with_status(steps: &[RunStep], status: StepStatus) -> bool {
    steps.iter().any(|step| step.status == status)
}

#[must_use]
pub fn is_run_finished(status: RunStatus) -> bool {
    matches!(
        status,
        RunStatus::Done | RunStatus::Failed | RunStatus::Cancelled
    )
}

#[must_use]
pub fn is_run_stopped(status: RunStatus) -> bool {
    matches!(status, RunStatus::Failed | RunStatus::Cancelled)
}

#[must_use]
pub fn is_step_finished(status: StepStatus) -> bool {
    matches!(
        status,
        StepStatus::Done | StepStatus::Failed | StepStatus::Skipped
    )
}

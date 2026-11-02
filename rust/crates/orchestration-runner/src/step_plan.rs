use orchestration_api::work::RunAssignment;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::identifiers::{SkillId, WorkflowId};
use orchestration_core::task::TaskDoer;
use orchestration_core::workflow::{AgentKind, Workflow, WorkflowAgent};
use orchestration_core::workflow_graph::{
    WorkflowProblem, upstream_agents, validate_workflow,
};
use thiserror::Error;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct StepPlan {
    pub name: String,
    pub agent: AgentKind,
    pub instruction: String,
    pub pinned_skills: Vec<SkillId>,
    pub uses_automatic_skills: bool,
    pub approval_policy: ApprovalPolicy,
    pub upstream_step_names: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum AssignmentProblem {
    #[error("a one-agent run needs exactly one step, not {0}")]
    UnexpectedStepCount(usize),
    #[error("the task runs a workflow but no workflow was sent")]
    MissingWorkflow,
    #[error("the task runs one agent but a workflow was sent")]
    UnexpectedWorkflow,
    #[error("the task runs workflow {} but another was sent", .0.0)]
    WrongWorkflow(WorkflowId),
    #[error(transparent)]
    InvalidWorkflow(#[from] WorkflowProblem),
    #[error("the workflow agent {0} has no agent kind")]
    MissingAgentKind(String),
    #[error("the run has no step named {0} to carry out")]
    UnknownStep(String),
}

pub fn plan_assigned_step(
    assignment: &RunAssignment,
) -> Result<StepPlan, AssignmentProblem> {
    match (&assignment.task.doer, &assignment.workflow) {
        (TaskDoer::OneAgent { agent }, None) => {
            plan_one_agent_step(assignment, *agent)
        }
        (TaskDoer::OneAgent { .. }, Some(_)) => {
            Err(AssignmentProblem::UnexpectedWorkflow)
        }
        (TaskDoer::Workflow { .. }, None) => {
            Err(AssignmentProblem::MissingWorkflow)
        }
        (TaskDoer::Workflow { workflow_id }, Some(workflow)) => {
            plan_workflow_step(*workflow_id, workflow, &assignment.step_name)
        }
    }
}

fn plan_one_agent_step(
    assignment: &RunAssignment,
    agent: AgentKind,
) -> Result<StepPlan, AssignmentProblem> {
    let steps = &assignment.run.steps;
    let [step] = steps.as_slice() else {
        return Err(AssignmentProblem::UnexpectedStepCount(steps.len()));
    };
    if step.name != assignment.step_name {
        let step_name = assignment.step_name.clone();
        return Err(AssignmentProblem::UnknownStep(step_name));
    }

    let task = &assignment.task;
    Ok(StepPlan {
        name: step.name.clone(),
        agent,
        instruction: task.title.clone(),
        pinned_skills: task.skills.clone(),
        uses_automatic_skills: task.uses_automatic_skills,
        approval_policy: task.approval_policy,
        upstream_step_names: Vec::new(),
    })
}

fn plan_workflow_step(
    expected_workflow: WorkflowId,
    workflow: &Workflow,
    step_name: &str,
) -> Result<StepPlan, AssignmentProblem> {
    if workflow.id != expected_workflow {
        return Err(AssignmentProblem::WrongWorkflow(expected_workflow));
    }
    validate_workflow(workflow)?;

    let agent = workflow.agents.iter().find(|agent| agent.name == step_name);
    let Some(agent) = agent else {
        return Err(AssignmentProblem::UnknownStep(step_name.to_owned()));
    };
    plan_agent_step(workflow, agent)
}

fn plan_agent_step(
    workflow: &Workflow,
    agent: &WorkflowAgent,
) -> Result<StepPlan, AssignmentProblem> {
    let Some(kind) = agent.kind else {
        return Err(AssignmentProblem::MissingAgentKind(agent.name.clone()));
    };

    let mut upstream_step_names = Vec::new();
    for upstream in upstream_agents(workflow, agent.id) {
        upstream_step_names.push(upstream.name.clone());
    }
    Ok(StepPlan {
        name: agent.name.clone(),
        agent: kind,
        instruction: agent.task.clone(),
        pinned_skills: agent.skills.clone(),
        uses_automatic_skills: agent.uses_automatic_skills,
        approval_policy: agent.approval_policy,
        upstream_step_names,
    })
}

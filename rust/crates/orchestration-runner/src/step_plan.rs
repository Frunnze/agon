use orchestration_api::work::RunAssignment;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::approval_levels::{
    ApprovalLevels, resolve_approval_policy,
};
use orchestration_core::identifiers::{SkillId, WorkflowId};
use orchestration_core::step_outcomes::list_step_choices;
use orchestration_core::task::TaskDoer;
use orchestration_core::workflow::{
    AgentKind, StepKind, Workflow, WorkflowAgent,
};
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
    pub outcome_choices: Vec<String>,
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
    #[error("the step {0} is answered by a person, not run by an agent")]
    PersonStep(String),
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
            plan_workflow_step(*workflow_id, workflow, assignment)
        }
    }
}

fn resolve_step_approval(
    assignment: &RunAssignment,
    step_choice: Option<ApprovalPolicy>,
) -> ApprovalPolicy {
    let project_choice = assignment
        .project
        .as_ref()
        .and_then(|project| project.approval_policy);
    resolve_approval_policy(ApprovalLevels {
        step: step_choice,
        project: project_choice,
        workspace: assignment.workspace_approval_policy,
    })
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
        approval_policy: resolve_step_approval(
            assignment,
            task.approval_policy,
        ),
        upstream_step_names: Vec::new(),
        outcome_choices: Vec::new(),
    })
}

fn plan_workflow_step(
    expected_workflow: WorkflowId,
    workflow: &Workflow,
    assignment: &RunAssignment,
) -> Result<StepPlan, AssignmentProblem> {
    let step_name = assignment.step_name.as_str();
    if workflow.id != expected_workflow {
        return Err(AssignmentProblem::WrongWorkflow(expected_workflow));
    }
    validate_workflow(workflow)?;

    let agent = workflow.agents.iter().find(|agent| agent.name == step_name);
    let Some(agent) = agent else {
        return Err(AssignmentProblem::UnknownStep(step_name.to_owned()));
    };
    plan_agent_step(workflow, agent, assignment)
}

fn plan_agent_step(
    workflow: &Workflow,
    agent: &WorkflowAgent,
    assignment: &RunAssignment,
) -> Result<StepPlan, AssignmentProblem> {
    if agent.step_kind == StepKind::Person {
        return Err(AssignmentProblem::PersonStep(agent.name.clone()));
    }
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
        approval_policy: resolve_step_approval(
            assignment,
            agent.approval_policy,
        ),
        upstream_step_names,
        outcome_choices: list_step_choices(workflow, agent.id),
    })
}

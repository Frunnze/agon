use crate::agent_kind_label::label_agent_kind;
use crate::approval::ApprovalPolicy;
use crate::device::RunnerTarget;
use crate::scope::WorkspaceScope;
use crate::workflow::{AgentConnection, StepKind, Workflow, WorkflowAgent};
use crate::workflow_graph::{
    agents_in_order, find_agent_by_id, upstream_agents,
};
use crate::yaml_text::{render_yaml_list, render_yaml_scalar};

const ALL_WORKSPACES_TEXT: &str = "all_workspaces";
const ANY_FREE_RUNNER_TEXT: &str = "any free runner";
const AGENT_NOT_SET_UP_TEXT: &str = "not-set-up";
const PERSON_KIND_LINE: &str = "    kind: person";

#[must_use]
pub fn render_workflow_document(workflow: &Workflow) -> String {
    let mut document = format!(
        "name: {}\navailable_in: {}\nsteps:\n",
        render_yaml_scalar(&workflow.name),
        render_availability(&workflow.availability)
    );
    for agent in agents_in_order(workflow) {
        document.push_str(&render_step(workflow, agent));
    }
    document
}

fn render_availability(availability: &WorkspaceScope) -> String {
    match availability {
        WorkspaceScope::AllWorkspaces => ALL_WORKSPACES_TEXT.to_owned(),
        WorkspaceScope::OnlyWorkspaces { workspaces } => {
            let workspace_texts: Vec<String> = workspaces
                .iter()
                .map(|workspace_id| workspace_id.0.to_string())
                .collect();
            render_yaml_list(&workspace_texts)
        }
    }
}

fn render_step(workflow: &Workflow, agent: &WorkflowAgent) -> String {
    let upstream_names: Vec<String> = upstream_agents(workflow, agent.id)
        .iter()
        .map(|upstream| upstream.name.clone())
        .collect();
    let mut step_lines = match agent.step_kind {
        StepKind::Agent => render_agent_lines(agent, &upstream_names),
        StepKind::Person => render_person_lines(agent, &upstream_names),
    };
    let outcome_texts = describe_outcomes(workflow, agent);
    if !outcome_texts.is_empty() {
        let outcomes = render_yaml_list(&outcome_texts);
        step_lines.push(format!("    outcomes: {outcomes}"));
    }
    let mut step = step_lines.join("\n");
    step.push('\n');
    step
}

fn render_agent_lines(
    agent: &WorkflowAgent,
    upstream_names: &[String],
) -> Vec<String> {
    let skill_texts: Vec<String> = agent
        .skills
        .iter()
        .map(|skill_id| skill_id.0.to_string())
        .collect();
    let agent_text =
        agent.kind.map_or(AGENT_NOT_SET_UP_TEXT, label_agent_kind);
    vec![
        format!("  - name: {}", render_yaml_scalar(&agent.name)),
        format!("    {}", render_runner_target(&agent.runs_on)),
        format!("    agent: {agent_text}"),
        format!("    after: {}", render_yaml_list(upstream_names)),
        format!("    task: {}", render_yaml_scalar(&agent.task)),
        format!("    skills: {}", render_yaml_list(&skill_texts)),
        format!("    automatic_skills: {}", agent.uses_automatic_skills),
        format!(
            "    asks_for_approval: {}",
            agent.approval_policy == ApprovalPolicy::AskBeforeRiskyActions
        ),
    ]
}

fn render_person_lines(
    agent: &WorkflowAgent,
    upstream_names: &[String],
) -> Vec<String> {
    vec![
        format!("  - name: {}", render_yaml_scalar(&agent.name)),
        PERSON_KIND_LINE.to_owned(),
        format!("    after: {}", render_yaml_list(upstream_names)),
        format!("    question: {}", render_yaml_scalar(&agent.task)),
    ]
}

fn describe_outcomes(
    workflow: &Workflow,
    agent: &WorkflowAgent,
) -> Vec<String> {
    let mut outcome_texts = Vec::new();
    for connection in &workflow.connections {
        if connection.from != agent.id {
            continue;
        }
        if let Some(condition) = &connection.condition {
            outcome_texts
                .push(describe_outcome(workflow, connection, condition));
        }
    }
    outcome_texts
}

fn describe_outcome(
    workflow: &Workflow,
    connection: &AgentConnection,
    condition: &str,
) -> String {
    let target_name = find_agent_by_id(workflow, connection.to).map_or_else(
        || connection.to.0.to_string(),
        |target| target.name.clone(),
    );
    match connection.round_limit {
        None => format!("{condition} -> {target_name}"),
        Some(round_limit) => format!(
            "{condition} -> {target_name}, at most {round_limit} rounds"
        ),
    }
}

fn render_runner_target(target: &RunnerTarget) -> String {
    match target {
        RunnerTarget::AnyFreeRunner => {
            format!("runs_on: {ANY_FREE_RUNNER_TEXT}")
        }
        RunnerTarget::SpecificRunner { device_id } => {
            format!("runs_on: {}", render_yaml_scalar(&device_id.0))
        }
        RunnerTarget::RunnerWithLabels { labels } => {
            format!("requires: {}", render_yaml_list(labels))
        }
    }
}

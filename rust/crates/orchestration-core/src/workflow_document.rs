use crate::agent_kind_label::label_agent_kind;
use crate::approval::ApprovalPolicy;
use crate::device::RunnerTarget;
use crate::scope::WorkspaceScope;
use crate::workflow::{Workflow, WorkflowAgent};
use crate::workflow_graph::{agents_in_order, upstream_agents};
use crate::yaml_text::{render_yaml_list, render_yaml_scalar};

const ALL_WORKSPACES_TEXT: &str = "all_workspaces";
const ANY_FREE_RUNNER_TEXT: &str = "any free runner";
const AGENT_NOT_SET_UP_TEXT: &str = "not-set-up";

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
    let skill_texts: Vec<String> = agent
        .skills
        .iter()
        .map(|skill_id| skill_id.0.to_string())
        .collect();
    let agent_text =
        agent.kind.map_or(AGENT_NOT_SET_UP_TEXT, label_agent_kind);

    let step_lines = [
        format!("  - name: {}", render_yaml_scalar(&agent.name)),
        format!("    {}", render_runner_target(&agent.runs_on)),
        format!("    agent: {agent_text}"),
        format!("    after: {}", render_yaml_list(&upstream_names)),
        format!("    task: {}", render_yaml_scalar(&agent.task)),
        format!("    skills: {}", render_yaml_list(&skill_texts)),
        format!("    automatic_skills: {}", agent.uses_automatic_skills),
        format!(
            "    asks_for_approval: {}",
            agent.approval_policy == ApprovalPolicy::AskBeforeRiskyActions
        ),
    ];
    let mut step = step_lines.join("\n");
    step.push('\n');
    step
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

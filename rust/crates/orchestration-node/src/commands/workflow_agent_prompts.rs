use orchestration_core::identifiers::WorkflowId;
use orchestration_core::naming::MAXIMUM_NAME_LENGTH;
use orchestration_core::scope::WorkspaceScope;
use orchestration_core::workflow::{Workflow, WorkflowAgent};

use crate::item_drafting::{DraftingContext, render_drafting_context};
use crate::node_error::NodeError;

const WORKFLOW_FORMAT_INSTRUCTIONS: &str = "Reply with one JSON object and \
nothing else: the complete workflow in the orchestration workflow format, \
with the fields id, name, availability, agents, connections and signature. \
Every agent has id, name, kind (claude_code, codex or gemini_cli), task, \
runs_on, skills, uses_automatic_skills, approval_policy and position. \
An agent's position is in canvas pixels from the top left: put agents that \
run one after another in rows 136 apart starting at vertical 16, and keep \
horizontal between 8 and 176. Keep the workflow id and set signature to \
null.";

pub(super) fn render_drafting_prompt(
    workflow_id: WorkflowId,
    context: &DraftingContext,
    description: &str,
) -> Result<String, NodeError> {
    let this_workspace_only = WorkspaceScope::OnlyWorkspaces {
        workspaces: vec![context.workspace.id],
    };
    let this_workspace_json = serde_json::to_string(&this_workspace_only)?;
    let everywhere_json =
        serde_json::to_string(&WorkspaceScope::AllWorkspaces)?;
    let workspace_context = render_drafting_context(context);
    Ok(format!(
        "Draft a new workflow.\nWorkflow id: {}\n{workspace_context}\n\
         What it should do:\n{description}\n\n\
         Choose its name: lowercase letters, digits and dashes, at most \
         {MAXIMUM_NAME_LENGTH} characters, and no workflow above has it. \
         Choose where it is available: {this_workspace_json} for this \
         workspace only, or {everywhere_json} when it fits every \
         workspace.\n{WORKFLOW_FORMAT_INSTRUCTIONS}",
        workflow_id.0
    ))
}

pub(super) fn render_change_prompt(
    workflow: &Workflow,
    change_request: &str,
) -> Result<String, NodeError> {
    let workflow_json = serde_json::to_string_pretty(workflow)?;
    Ok(format!(
        "Change this workflow.\nCurrent workflow:\n{workflow_json}\n\
         Requested change:\n{change_request}\n\n\
         {WORKFLOW_FORMAT_INSTRUCTIONS}"
    ))
}

pub(super) fn render_fill_prompt(
    workflow: &Workflow,
    agent: &WorkflowAgent,
) -> Result<String, NodeError> {
    let workflow_json = serde_json::to_string_pretty(workflow)?;
    Ok(format!(
        "Fill in every setting of the agent {} (id {}) in this workflow: \
         its kind, task, runner, skills and approval, so it fits the \
         agents around it. Change nothing else.\nCurrent workflow:\n\
         {workflow_json}\n\n{WORKFLOW_FORMAT_INSTRUCTIONS}",
        agent.name, agent.id.0
    ))
}

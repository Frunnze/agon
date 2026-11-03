use orchestration_core::identifiers::WorkflowId;
use orchestration_core::naming::MAXIMUM_NAME_LENGTH;
use orchestration_core::scope::WorkspaceScope;
use orchestration_core::workflow::{Workflow, WorkflowAgent};

use crate::item_drafting::{
    APPROVAL_POLICY_FORMS, DraftingContext, RUNS_ON_FORMS,
    render_drafting_context,
};
use crate::node_error::NodeError;

const WORKFLOW_FORMAT_OPENING: &str = "Reply with one JSON object and \
nothing else: the complete workflow in the orchestration workflow format, \
with the fields id, name, availability, agents, connections and signature. \
Every agent has id (a new UUID), name, step_kind (agent, or person for a \
step a person answers), kind (claude_code, codex or gemini_cli), task, \
runs_on, skills (a list of skill ids listed above), uses_automatic_skills \
(true or false), approval_policy and position.";
const WORKFLOW_BRANCHING_RULES: &str = "A step with \"step_kind\": \
\"person\" pauses the run until a person answers it: its task is the \
question shown to the person, and its kind, runs_on and skills are \
ignored. A connection may carry \"condition\": \"<outcome>\", 1 to 40 \
lowercase letters, digits, spaces or dashes, unique among the connections \
that leave one step: it is taken only when that step ends with that \
outcome, while a connection without a condition is always taken. An agent \
step with such connections ends its final message with a line OUTCOME: \
<outcome>; a person answers with one of the outcomes, and approve or \
approved picks an outcome named approved. A step runs once every step \
connected into it has finished or been skipped and at least one taken \
connection reaches it; otherwise it is skipped. To loop back, give a \
connection a condition and \"round_limit\": 1 to 10, and point it at an \
earlier step that leads to its source: when taken it reruns that step and \
every step after it, at most round_limit times. Only such loop \
connections may close a cycle.";
const WORKFLOW_FORMAT_CLOSING: &str = "An agent's position is in canvas \
pixels from the top left, {\"horizontal\": <pixels>, \"vertical\": \
<pixels>}: any position will do, the steps are laid out for you. Each \
connection is {\"from\": \"<agent id>\", \"to\": \"<agent id>\", \
\"condition\": null, \"round_limit\": null}. Keep the workflow id and \
set signature to null.";

fn render_workflow_format_instructions() -> String {
    format!(
        "{WORKFLOW_FORMAT_OPENING} runs_on is {RUNS_ON_FORMS}. \
         approval_policy is {APPROVAL_POLICY_FORMS}. \
         {WORKFLOW_FORMAT_CLOSING} {WORKFLOW_BRANCHING_RULES}"
    )
}

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
    let format_instructions = render_workflow_format_instructions();
    Ok(format!(
        "Draft a new workflow.\nWorkflow id: {}\n{workspace_context}\n\
         What it should do:\n{description}\n\n\
         Choose its name: lowercase letters, digits and dashes, at most \
         {MAXIMUM_NAME_LENGTH} characters, and no workflow above has it. \
         Choose where it is available: {this_workspace_json} for this \
         workspace only, or {everywhere_json} when it fits every \
         workspace.\n{format_instructions}",
        workflow_id.0
    ))
}

pub(super) fn render_change_prompt(
    workflow: &Workflow,
    change_request: &str,
) -> Result<String, NodeError> {
    let workflow_json = serde_json::to_string_pretty(workflow)?;
    let format_instructions = render_workflow_format_instructions();
    Ok(format!(
        "Change this workflow.\nCurrent workflow:\n{workflow_json}\n\
         Requested change:\n{change_request}\n\n{format_instructions}"
    ))
}

pub(super) fn render_fill_prompt(
    workflow: &Workflow,
    agent: &WorkflowAgent,
) -> Result<String, NodeError> {
    let workflow_json = serde_json::to_string_pretty(workflow)?;
    let format_instructions = render_workflow_format_instructions();
    Ok(format!(
        "Fill in every setting of the agent {} (id {}) in this workflow: \
         its kind, task, runner, skills and approval, so it fits the \
         agents around it. Change nothing else.\nCurrent workflow:\n\
         {workflow_json}\n\n{format_instructions}",
        agent.name, agent.id.0
    ))
}

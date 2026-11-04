use chrono::Utc;
use orchestration_api::work::TaskStart;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{
    TaskId, WorkflowAgentId, WorkflowId, WorkspaceId, generate_uuid,
};
use orchestration_core::task::{Task, TaskDoer, TaskPlace, TaskStatus};
use orchestration_core::workflow::AgentKind;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::drafting_context_reading::read_drafting_context;
use super::task_commands::queue_task;
use super::workflow_agent_prompts::{
    render_change_prompt, render_drafting_prompt, render_fill_prompt,
};
use super::workflow_view::read_stored_workflow;
use crate::command_reply::encode_reply;
use crate::content_sealing::open_workflow;
use crate::node::Node;
use crate::node_error::NodeError;

pub(super) const WORKFLOW_AGENT_COMMAND_NAMES: [&str; 3] =
    ["draft_workflow", "change_workflow", "fill_agent_settings"];
pub(super) const DRAFTING_AGENT_KIND: AgentKind = AgentKind::ClaudeCode;
const DRAFT_WORKFLOW_TITLE: &str = "Draft new workflow";

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum WorkflowAgentCommand {
    DraftWorkflow {
        workspace_id: WorkspaceId,
        description: String,
    },
    ChangeWorkflow {
        workspace_id: WorkspaceId,
        workflow_id: WorkflowId,
        request: String,
    },
    FillAgentSettings {
        workspace_id: WorkspaceId,
        workflow_id: WorkflowId,
        agent_id: WorkflowAgentId,
    },
}

#[derive(Debug, Serialize)]
struct WorkflowAgentTaskView {
    workflow_id: WorkflowId,
    task_id: TaskId,
    drafter: AgentKind,
}

struct AgentTaskPlan {
    workspace_id: WorkspaceId,
    workflow_id: WorkflowId,
    task: Task,
}

pub(super) async fn handle_workflow_agent_command(
    node: &Node,
    command: WorkflowAgentCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    let plan = match command {
        WorkflowAgentCommand::DraftWorkflow {
            workspace_id,
            description,
        } => {
            require_text(&description, "workflow description")?;
            let workflow_id = WorkflowId(generate_uuid());
            let this_device_id = session.identity.device_id();
            let context =
                read_drafting_context(&client, workspace_id, &this_device_id)
                    .await?;
            let details =
                render_drafting_prompt(workflow_id, &context, &description)?;
            let title = DRAFT_WORKFLOW_TITLE.to_owned();
            AgentTaskPlan {
                workspace_id,
                workflow_id,
                task: build_agent_task(workspace_id, title, details),
            }
        }
        WorkflowAgentCommand::ChangeWorkflow {
            workspace_id,
            workflow_id,
            request,
        } => {
            require_text(&request, "change request")?;
            let stored = read_stored_workflow(&client, workflow_id).await?;
            let workflow = open_workflow(&session.keyring, &stored.workflow)?;
            let details = render_change_prompt(&workflow, &request)?;
            let title = format!("Change workflow {}", workflow.name);
            AgentTaskPlan {
                workspace_id,
                workflow_id,
                task: build_agent_task(workspace_id, title, details),
            }
        }
        WorkflowAgentCommand::FillAgentSettings {
            workspace_id,
            workflow_id,
            agent_id,
        } => {
            let stored = read_stored_workflow(&client, workflow_id).await?;
            let workflow = open_workflow(&session.keyring, &stored.workflow)?;
            let agent = workflow
                .agents
                .iter()
                .find(|agent| agent.id == agent_id)
                .ok_or_else(|| NodeError::NotFound {
                    kind: "workflow agent",
                    identifier: agent_id.0.to_string(),
                })?;
            let details = render_fill_prompt(&workflow, agent)?;
            let title =
                format!("Fill in agent {} of {}", agent.name, workflow.name);
            AgentTaskPlan {
                workspace_id,
                workflow_id,
                task: build_agent_task(workspace_id, title, details),
            }
        }
    };

    queue_task(
        &session,
        &client,
        plan.workspace_id,
        &plan.task,
        TaskStart::Now,
    )
    .await?;
    encode_reply(&WorkflowAgentTaskView {
        workflow_id: plan.workflow_id,
        task_id: plan.task.id,
        drafter: DRAFTING_AGENT_KIND,
    })
}

pub(super) fn require_text(
    text: &str,
    field: &'static str,
) -> Result<(), NodeError> {
    if text.trim().is_empty() {
        return Err(NodeError::EmptyText { field });
    }
    Ok(())
}

pub(super) fn build_agent_task(
    workspace_id: WorkspaceId,
    title: String,
    details: String,
) -> Task {
    Task {
        id: TaskId(generate_uuid()),
        title,
        details,
        place: TaskPlace::InWorkspace { workspace_id },
        doer: TaskDoer::OneAgent {
            agent: DRAFTING_AGENT_KIND,
        },
        runs_on: RunnerTarget::AnyFreeRunner,
        agent_place: None,
        skills: Vec::new(),
        uses_automatic_skills: false,
        approval_policy: Some(ApprovalPolicy::NeverAsk),
        schedule: None,
        status: TaskStatus::ToDo,
        created_at: Utc::now(),
    }
}

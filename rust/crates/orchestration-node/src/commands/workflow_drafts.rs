use orchestration_api::catalog::WorkflowListing;
use orchestration_core::identifiers::{TaskId, WorkflowId, WorkspaceId};
use orchestration_core::run::{ChatAuthor, Run, RunStatus};
use orchestration_core::run_lifecycle::is_run_finished;
use orchestration_core::scope_rules::workspace_scope_includes;
use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_layout::lay_out_workflow;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::workflow_commands::{
    prepare_workflow_resave, prepare_workflow_upload, show_workflow,
};
use super::workflow_view::WorkflowView;
use crate::command_reply::encode_reply;
use crate::content_sealing::{WorkspaceKeyring, open_run, open_workflow};
use crate::item_drafting::{check_new_workflow_draft, cut_json_object};
use crate::node::{DeviceSession, Node};
use crate::node_error::NodeError;
use crate::server_client::SignedServerClient;

pub(super) const WORKFLOW_DRAFT_COMMAND_NAMES: [&str; 1] =
    ["workflow_draft_status"];
const CANCELLED_REASON: &str = "the drafting run was cancelled";

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum WorkflowDraftCommand {
    WorkflowDraftStatus {
        workspace_id: WorkspaceId,
        task_id: TaskId,
        workflow_id: WorkflowId,
    },
}

#[derive(Debug, Serialize)]
#[serde(tag = "state", rename_all = "snake_case")]
enum DraftStatus {
    Working,
    Done { workflow: Box<WorkflowView> },
}

pub(super) async fn handle_workflow_draft_command(
    node: &Node,
    command: WorkflowDraftCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    let WorkflowDraftCommand::WorkflowDraftStatus {
        workspace_id,
        task_id,
        workflow_id,
    } = command;

    let answer = take_draft_answer(&session, &client, task_id).await?;
    let Some(final_message) = answer else {
        return encode_reply(&DraftStatus::Working);
    };

    let drafted = parse_drafted_workflow(&final_message, workflow_id)?;
    save_draft(&session, &client, workspace_id, &drafted).await?;
    let workflow = show_workflow(&session, &client, workflow_id).await?;
    encode_reply(&DraftStatus::Done {
        workflow: Box::new(workflow),
    })
}

pub(super) async fn take_draft_answer(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    task_id: TaskId,
) -> Result<Option<String>, NodeError> {
    let runs = client.list_task_runs(task_id).await?;
    let Some(latest_run) = runs.iter().max_by_key(|run| run.number) else {
        return Ok(None);
    };
    let ending = latest_run.status;
    if !is_run_finished(ending) {
        return Ok(None);
    }

    if ending != RunStatus::Cancelled {
        client.delete_task(task_id).await?;
    }
    let final_message = read_draft_answer(&session.keyring, latest_run)?;
    Ok(Some(final_message))
}

fn read_draft_answer(
    keyring: &WorkspaceKeyring,
    run: &Run,
) -> Result<String, NodeError> {
    if run.status != RunStatus::Done {
        let reason = run
            .failure
            .as_ref()
            .map_or(CANCELLED_REASON, |failure| failure.reason.as_str());
        return Err(NodeError::DraftFailed(reason.to_owned()));
    }
    let opened_run = open_run(keyring, run)?;
    read_final_agent_message(&opened_run)
}

fn read_final_agent_message(run: &Run) -> Result<String, NodeError> {
    let final_message = run
        .chat
        .iter()
        .rev()
        .find(|message| message.author == ChatAuthor::Agent);
    let final_message = final_message.ok_or(NodeError::DraftWithoutAnswer)?;
    Ok(final_message.text.clone())
}

fn parse_drafted_workflow(
    final_message: &str,
    expected_id: WorkflowId,
) -> Result<Workflow, NodeError> {
    let workflow_text = cut_json_object(final_message).ok_or_else(|| {
        NodeError::DraftNotWorkflow("the answer holds no JSON object".into())
    })?;
    let drafted: Workflow = serde_json::from_str(workflow_text)
        .map_err(|error| NodeError::DraftNotWorkflow(error.to_string()))?;
    if drafted.id != expected_id {
        return Err(NodeError::DraftForAnotherWorkflow {
            expected: expected_id.0,
            found: drafted.id.0,
        });
    }
    let unsigned = Workflow {
        signature: None,
        ..drafted
    };
    Ok(lay_out_workflow(&unsigned))
}

async fn save_draft(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
    drafted: &Workflow,
) -> Result<(), NodeError> {
    let stored_workflows = client.list_workflows().await?;
    let stored = stored_workflows
        .iter()
        .find(|listing| listing.workflow.id == drafted.id);
    let Some(stored) = stored else {
        let taken_names = list_workflow_names(&stored_workflows, workspace_id);
        check_new_workflow_draft(drafted, workspace_id, &taken_names)?;
        let request = prepare_workflow_upload(session, workspace_id, drafted)?;
        return client.create_workflow(&request).await;
    };

    let opened = open_workflow(&session.keyring, &stored.workflow)?;
    let opened_without_signature = Workflow {
        signature: None,
        ..opened
    };
    if opened_without_signature == *drafted {
        return Ok(());
    }
    let request = prepare_workflow_resave(
        session,
        workspace_id,
        drafted,
        &stored.workflow,
    )?;
    client.update_workflow(drafted.id, &request).await
}

fn list_workflow_names(
    listings: &[WorkflowListing],
    workspace_id: WorkspaceId,
) -> Vec<String> {
    let mut names = Vec::new();
    for listing in listings {
        let workflow = &listing.workflow;
        if workspace_scope_includes(&workflow.availability, workspace_id) {
            names.push(workflow.name.clone());
        }
    }
    names
}

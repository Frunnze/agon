use orchestration_api::work::TaskStart;
use orchestration_core::identifiers::{TaskId, WorkspaceId};
use orchestration_core::task::Task;
use orchestration_core::workflow::AgentKind;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::drafting_context_reading::read_drafting_context;
use super::task_commands::queue_task;
use super::workflow_agent_commands::{
    DRAFTING_AGENT_KIND, build_agent_task, require_text,
};
use super::workflow_drafts::take_draft_answer;
use crate::command_reply::encode_reply;
use crate::item_drafting::{
    CheckedDraft, DraftChange, DraftKind, RepositoryDraft, add_chosen_folders,
    check_item_draft, parse_item_answer, render_drafting_prompt,
    require_chosen_folders, require_project_folders,
};
use crate::node::{DeviceSession, Node};
use crate::node_error::NodeError;

pub(super) const ITEM_DRAFT_COMMAND_NAMES: [&str; 2] =
    ["draft_item", "item_draft_status"];
const REQUEST_FIELD: &str = "request";
const CHANGE_NOTE_FIELD: &str = "change note";

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum ItemDraftCommand {
    DraftItem {
        workspace_id: WorkspaceId,
        kind: DraftKind,
        request: String,
        started_from: Option<String>,
        change: Option<DraftChange>,
        #[serde(default)]
        chosen_folders: Vec<RepositoryDraft>,
    },
    ItemDraftStatus {
        workspace_id: WorkspaceId,
        task_id: TaskId,
        kind: DraftKind,
        #[serde(default)]
        chosen_folders: Vec<RepositoryDraft>,
    },
}

#[derive(Debug, Serialize)]
struct DraftingTaskView {
    task_id: TaskId,
    drafter: AgentKind,
}

#[derive(Debug, Serialize)]
#[serde(tag = "state", rename_all = "snake_case")]
enum ItemDraftProgress {
    Working,
    Done(CheckedDraft),
}

struct ItemDraftOrder {
    workspace_id: WorkspaceId,
    kind: DraftKind,
    request: String,
    started_from: Option<String>,
    change: Option<DraftChange>,
    chosen_folders: Vec<RepositoryDraft>,
}

pub(super) async fn handle_item_draft_command(
    node: &Node,
    command: ItemDraftCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    match command {
        ItemDraftCommand::DraftItem {
            workspace_id,
            kind,
            request,
            started_from,
            change,
            chosen_folders,
        } => {
            let order = ItemDraftOrder {
                workspace_id,
                kind,
                request,
                started_from,
                change,
                chosen_folders,
            };
            let task = queue_drafting_task(&session, &order).await?;
            encode_reply(&DraftingTaskView {
                task_id: task.id,
                drafter: DRAFTING_AGENT_KIND,
            })
        }
        ItemDraftCommand::ItemDraftStatus {
            workspace_id,
            task_id,
            kind,
            chosen_folders,
        } => {
            require_project_folders(kind, &chosen_folders)?;
            let progress = read_item_draft(
                &session,
                workspace_id,
                task_id,
                kind,
                &chosen_folders,
            )
            .await?;
            encode_reply(&progress)
        }
    }
}

async fn queue_drafting_task(
    session: &DeviceSession,
    order: &ItemDraftOrder,
) -> Result<Task, NodeError> {
    require_text(&order.request, REQUEST_FIELD)?;
    if let Some(change) = &order.change {
        require_text(&change.note, CHANGE_NOTE_FIELD)?;
    }
    let this_device_id = session.identity.device_id();
    require_chosen_folders(
        &this_device_id,
        order.kind,
        &order.chosen_folders,
    )?;

    let client = session.client();
    let context =
        read_drafting_context(&client, order.workspace_id, &this_device_id)
            .await?;
    let details = render_drafting_prompt(
        &context,
        order.kind,
        &order.request,
        order.started_from.as_deref(),
        order.change.as_ref(),
        &order.chosen_folders,
    )?;

    let title = format!("Draft new {}", order.kind.name());
    let task = build_agent_task(
        order.workspace_id,
        title,
        details,
        DRAFTING_AGENT_KIND,
    );
    queue_task(session, &client, order.workspace_id, &task, TaskStart::Now)
        .await?;
    Ok(task)
}

async fn read_item_draft(
    session: &DeviceSession,
    workspace_id: WorkspaceId,
    task_id: TaskId,
    kind: DraftKind,
    chosen_folders: &[RepositoryDraft],
) -> Result<ItemDraftProgress, NodeError> {
    let client = session.client();
    let answer = take_draft_answer(session, &client, task_id).await?;
    let Some(final_message) = answer else {
        return Ok(ItemDraftProgress::Working);
    };

    let answered = parse_item_answer(kind, &final_message)?;
    let drafted = add_chosen_folders(answered, chosen_folders);
    let this_device_id = session.identity.device_id();
    let context =
        read_drafting_context(&client, workspace_id, &this_device_id).await?;
    let checked = check_item_draft(&context, &drafted);
    Ok(ItemDraftProgress::Done(checked))
}

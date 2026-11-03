use chrono::{DateTime, Utc};
use orchestration_api::work::SendChatMessageRequest;
use orchestration_core::device::RunnerLink;
use orchestration_core::identifiers::{RunId, TaskId, WorkspaceId};
use orchestration_core::run::{ChatAuthor, ChatMessage, Run};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::person_answers::{
    AskedQuestion, answer_person_step, list_open_person_steps,
};
use crate::command_reply::encode_reply;
use crate::content_sealing::{open_run, seal_chat_message};
use crate::node::Node;
use crate::node_error::NodeError;
use crate::views::{RunProgress, describe_run_progress};

pub(super) const RUN_COMMAND_NAMES: [&str; 7] = [
    "list_runs",
    "show_run",
    "cancel_run",
    "retry_run",
    "send_chat_message",
    "list_person_steps",
    "answer_person_step",
];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum RunCommand {
    ListRuns {
        task_id: TaskId,
    },
    ShowRun {
        run_id: RunId,
    },
    CancelRun {
        run_id: RunId,
    },
    RetryRun {
        run_id: RunId,
    },
    SendChatMessage {
        workspace_id: WorkspaceId,
        run_id: RunId,
        text: String,
    },
    ListPersonSteps,
    AnswerPersonStep {
        run_id: RunId,
        step_name: String,
        answer: String,
    },
}

#[derive(Debug, Serialize)]
struct RunView {
    run: Run,
    progress: RunProgress,
    link: RunnerLink,
    link_lost_at: Option<DateTime<Utc>>,
}

pub(super) async fn handle_run_command(
    node: &Node,
    command: RunCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    match command {
        RunCommand::ListRuns { task_id } => {
            let mut opened_runs = Vec::new();
            for run in client.list_task_runs(task_id).await? {
                opened_runs.push(open_run(&session.keyring, &run)?);
            }
            encode_reply(&opened_runs)
        }
        RunCommand::ShowRun { run_id } => {
            let run = client.read_run(run_id).await?;
            let opened_run = open_run(&session.keyring, &run)?;
            let progress = describe_run_progress(&opened_run);
            let live_report = node
                .peer_side()
                .ok()
                .and_then(|peer_side| peer_side.watches.link_report(run_id));
            let (link, link_lost_at) = live_report
                .unwrap_or((opened_run.link, opened_run.link_lost_at));
            encode_reply(&RunView {
                run: opened_run,
                progress,
                link,
                link_lost_at,
            })
        }
        RunCommand::CancelRun { run_id } => {
            client.cancel_run(run_id).await?;
            Ok(Value::Null)
        }
        RunCommand::RetryRun { run_id } => {
            client.retry_run(run_id).await?;
            Ok(Value::Null)
        }
        RunCommand::SendChatMessage {
            workspace_id,
            run_id,
            text,
        } => {
            if text.trim().is_empty() {
                return Err(NodeError::EmptyText { field: "message" });
            }
            let message = ChatMessage {
                at: Utc::now(),
                author: ChatAuthor::You,
                text,
                is_error: false,
                waiting_to_send: false,
            };
            let workspace_key = session.keyring.key_for(workspace_id)?;
            if send_over_live_link(node, run_id, &message.text).await? {
                return encode_reply(&message);
            }
            let request = SendChatMessageRequest {
                message: seal_chat_message(workspace_key, &message)?,
            };
            client.send_chat_message(run_id, &request).await?;
            encode_reply(&message)
        }
        RunCommand::ListPersonSteps => {
            encode_reply(&list_open_person_steps(&session).await?)
        }
        RunCommand::AnswerPersonStep {
            run_id,
            step_name,
            answer,
        } => {
            let question = AskedQuestion {
                run_id,
                step_name: &step_name,
            };
            encode_reply(
                &answer_person_step(&session, question, &answer).await?,
            )
        }
    }
}

async fn send_over_live_link(
    node: &Node,
    run_id: RunId,
    text: &str,
) -> Result<bool, NodeError> {
    let Ok(peer_side) = node.peer_side() else {
        return Ok(false);
    };
    peer_side.watches.send_chat(run_id, text).await
}

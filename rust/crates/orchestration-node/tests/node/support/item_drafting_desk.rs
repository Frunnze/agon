use orchestration_api::work::RunEvent;
use orchestration_core::identifiers::RunId;
use orchestration_core::run::RunFailure;
use proptest::prelude::*;
use serde_json::{Value, json};

use super::command_builders::PreparedWorkspace;
use super::drafting_desk::{DraftingDesk, agent_message};
use super::test_device::{TestDevice, read_text};

const DRAFTED_KINDS: [&str; 5] = ["task", "job", "project", "skill", "rule"];
const CHOSEN_FOLDERS_FIELD: &str = "chosen_folders";

#[derive(Debug)]
pub struct StartedItemDraft {
    pub task_id: String,
    pub kind: String,
    pub details: String,
    chosen_folders: Value,
    run_id: RunId,
    step_name: String,
}

pub fn draft_item_command(
    prepared: &PreparedWorkspace,
    kind: &str,
    request: &str,
) -> Value {
    json!({
        "command": "draft_item",
        "workspace_id": prepared.workspace_id,
        "kind": kind,
        "request": request,
    })
}

pub fn drafted_task_answer(project_id: &str) -> Value {
    json!({
        "title": "Ship release 2.4",
        "details": "Bump the version and tag it",
        "project_id": project_id,
        "doer": { "kind": "one_agent", "agent": "claude_code" },
        "runs_on": { "kind": "any_free_runner" },
        "agent_place": "local_process",
        "skills": [],
        "uses_automatic_skills": false,
        "approval_policy": "ask_before_risky_actions",
        "schedule": null,
    })
}

pub fn drafted_project_answer(address: &str) -> Value {
    json!({
        "name": "billing",
        "repositories": [{ "address": address, "default_branch": "main" }],
        "agent_access": "read_only",
    })
}

pub fn start_item_draft(
    desk: &DraftingDesk,
    command: &Value,
) -> Result<StartedItemDraft, String> {
    let drafting = desk.prepared.device.run(command)?;
    let assignment = desk.claim_drafting_run()?;
    let step = assignment.run.steps.first().ok_or("the run has no step")?;
    let chosen_folders = command
        .get(CHOSEN_FOLDERS_FIELD)
        .cloned()
        .unwrap_or_else(|| json!([]));
    Ok(StartedItemDraft {
        task_id: read_text(&drafting, "/task_id")?,
        kind: read_text(command, "/kind")?,
        details: assignment.task.details.clone(),
        chosen_folders,
        run_id: assignment.run.id,
        step_name: step.name.clone(),
    })
}

pub fn finish_item_draft(
    desk: &DraftingDesk,
    draft: &StartedItemDraft,
    final_message: &str,
) -> Result<(), String> {
    let events = vec![agent_message(final_message), RunEvent::Finished];
    desk.post_run_events(draft.run_id, events)
}

pub fn fail_item_draft(
    desk: &DraftingDesk,
    draft: &StartedItemDraft,
    reason: &str,
) -> Result<(), String> {
    let failed = RunEvent::Failed {
        failure: RunFailure {
            step_name: draft.step_name.clone(),
            runner: None,
            reason: reason.to_owned(),
            retry_runs_on_same_runner: true,
        },
    };
    desk.post_run_events(draft.run_id, vec![failed])
}

pub fn item_draft_status(
    desk: &DraftingDesk,
    draft: &StartedItemDraft,
) -> Value {
    desk.prepared.device.send(&json!({
        "command": "item_draft_status",
        "workspace_id": desk.prepared.workspace_id,
        "task_id": draft.task_id,
        "kind": draft.kind,
        "chosen_folders": draft.chosen_folders,
    }))
}

pub fn read_device_id(device: &TestDevice) -> Result<String, String> {
    let status = device.run(&json!({ "command": "status" }))?;
    read_text(&status, "/device_id")
}

pub fn drafted_kind_strategy() -> impl Strategy<Value = &'static str> {
    proptest::sample::select(DRAFTED_KINDS.to_vec())
}

use std::sync::Arc;

use chrono::Utc;
use orchestration_api::work::{RunAssignment, RunEvent, RunEventsRequest};
use orchestration_core::identifiers::RunId;
use orchestration_core::run::{ChatAuthor, ChatMessage};
use orchestration_node::runner_bridge::NodeRunnerServer;
use orchestration_runner::runner_server::RunnerServer;
use serde_json::{Value, json};
use tokio::runtime::Runtime;

use super::command_builders::{PreparedWorkspace, prepare_workspace};
use super::runner_access::{claim_next_assignment, open_runner, test_runtime};
use super::test_device::{describe, read_text};

const DRAFTED_NAME: &str = "feature-pipeline";
const PLANNING_AGENT_ID: &str = "00000000-0000-0000-0000-000000000011";

#[derive(Debug)]
pub struct DraftingDesk {
    pub prepared: PreparedWorkspace,
    runtime: Runtime,
    runner: Arc<NodeRunnerServer>,
}

#[derive(Debug)]
pub struct StartedDraft {
    pub task_id: String,
    pub workflow_id: String,
    pub run_id: RunId,
    pub step_name: String,
}

fn open_desk() -> Result<DraftingDesk, String> {
    let prepared = prepare_workspace()?;
    let runtime = test_runtime()?;
    let runner = open_runner(&prepared)?;
    Ok(DraftingDesk {
        prepared,
        runtime,
        runner,
    })
}

pub fn open_desk_or_panic() -> DraftingDesk {
    match open_desk() {
        Ok(desk) => desk,
        Err(message) => panic!("the drafting desk opens: {message}"),
    }
}

pub fn draft_command(prepared: &PreparedWorkspace) -> Value {
    json!({
        "command": "draft_workflow",
        "workspace_id": prepared.workspace_id,
        "description": "Plan, then build",
    })
}

pub fn drafted_workflow_json(workflow_id: &str, agent_task: &str) -> String {
    let availability = json!({ "kind": "all_workspaces" });
    drafted_workflow_with(workflow_id, DRAFTED_NAME, &availability, agent_task)
}

pub fn drafted_workflow_with(
    workflow_id: &str,
    name: &str,
    availability: &Value,
    agent_task: &str,
) -> String {
    json!({
        "id": workflow_id,
        "name": name,
        "availability": availability,
        "agents": [{
            "id": PLANNING_AGENT_ID,
            "name": "plan",
            "kind": "claude_code",
            "task": agent_task,
            "runs_on": { "kind": "any_free_runner" },
            "skills": [],
            "uses_automatic_skills": false,
            "approval_policy": "never_ask",
            "position": { "horizontal": 0.0, "vertical": 0.0 },
        }],
        "connections": [],
        "signature": null,
    })
    .to_string()
}

pub fn agent_message(text: &str) -> RunEvent {
    RunEvent::ChatAppended {
        message: ChatMessage {
            at: Utc::now(),
            author: ChatAuthor::Agent,
            text: text.to_owned(),
            is_error: false,
            waiting_to_send: false,
        },
    }
}

impl DraftingDesk {
    pub fn claim_drafting_run(&self) -> Result<RunAssignment, String> {
        claim_next_assignment(&self.runner, &self.runtime)
    }

    pub fn post_run_events(
        &self,
        run_id: RunId,
        events: Vec<RunEvent>,
    ) -> Result<(), String> {
        let request = RunEventsRequest { events };
        let posting = self.runner.post_run_events(run_id, &request);
        self.runtime.block_on(posting).map_err(describe)
    }

    pub fn start(&self, command: &Value) -> Result<StartedDraft, String> {
        let drafting = self.prepared.device.run(command)?;
        let assignment = self.claim_drafting_run()?;
        let step =
            assignment.run.steps.first().ok_or("the run has no step")?;
        Ok(StartedDraft {
            task_id: read_text(&drafting, "/task_id")?,
            workflow_id: read_text(&drafting, "/workflow_id")?,
            run_id: assignment.run.id,
            step_name: step.name.clone(),
        })
    }

    pub fn post(
        &self,
        draft: &StartedDraft,
        events: Vec<RunEvent>,
    ) -> Result<(), String> {
        self.post_run_events(draft.run_id, events)
    }

    pub fn finish(
        &self,
        draft: &StartedDraft,
        final_message: &str,
    ) -> Result<(), String> {
        let events = vec![agent_message(final_message), RunEvent::Finished];
        self.post(draft, events)
    }

    pub fn status_reply(&self, draft: &StartedDraft) -> Value {
        self.prepared.device.send(&json!({
            "command": "workflow_draft_status",
            "workspace_id": self.prepared.workspace_id,
            "task_id": draft.task_id,
            "workflow_id": draft.workflow_id,
        }))
    }

    pub fn count_task_runs(&self, task_id: &str) -> Result<usize, String> {
        let runs = self.prepared.device.run(&json!({
            "command": "list_runs",
            "task_id": task_id,
        }))?;
        let listed = runs.as_array().ok_or("the runs are not a list")?;
        Ok(listed.len())
    }

    pub fn list_workflows(&self) -> Result<Value, String> {
        self.prepared.device.run(&json!({
            "command": "list_workflows",
            "workspace_id": self.prepared.workspace_id,
        }))
    }

    pub fn sign(&self, workflow_id: &str) -> Result<Value, String> {
        self.prepared.device.run(&json!({
            "command": "sign_workflow",
            "workflow_id": workflow_id,
        }))
    }
}

pub fn start_or_panic(desk: &DraftingDesk, command: &Value) -> StartedDraft {
    match desk.start(command) {
        Ok(draft) => draft,
        Err(message) => panic!("the draft starts: {message}"),
    }
}

pub fn finish_or_panic(desk: &DraftingDesk, draft: &StartedDraft, text: &str) {
    if let Err(message) = desk.finish(draft, text) {
        panic!("the draft finishes: {message}");
    }
}

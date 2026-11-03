use std::time::Duration;

use serde_json::{Value, json};
use tempfile::TempDir;

use super::git_origin::{LOCAL_REPOSITORY_ADDRESS, create_local_origin};
use super::hosting_steps::{HostingDevice, start_hosting_device_with_relay};
use super::node_process::NodeProcess;
use super::test_device::{TestDevice, describe, read_text};
use super::two_nodes::{RunnerFolders, start_runner_process};
use super::waiting::wait_for;

pub const PLAN_DETAILS: &str = "Plan the change over the peer link";
pub const WORKTREES_FOLDER_NAME: &str = "worktrees";
const ORIGINS_FOLDER_NAME: &str = "origins";
const RUNNER_NAME: &str = "travel-runner";
const FLOW_LIMIT: Duration = Duration::from_secs(120);

#[derive(Debug)]
pub struct HostedRunner {
    pub hosting: HostingDevice,
    pub runner: NodeProcess,
    pub workspace_id: String,
    pub records: TempDir,
    pub runner_data: TempDir,
}

pub fn start_runner_beside_host(
    peer_relay: &str,
) -> Result<HostedRunner, String> {
    let hosting = start_hosting_device_with_relay(peer_relay)?;
    let workspace_id = read_text(&hosting.account, "/workspaces/0/id")?;
    let records = TempDir::new().map_err(describe)?;
    let origin_root = records.path().join(ORIGINS_FOLDER_NAME);
    create_local_origin(&origin_root)?;
    let runner_data = TempDir::new().map_err(describe)?;
    let folders = RunnerFolders {
        runner_data: runner_data.path(),
        origin_root: &origin_root,
        records: records.path(),
    };
    let runner = start_runner_process(folders, peer_relay)?;
    Ok(HostedRunner {
        hosting,
        runner,
        workspace_id,
        records,
        runner_data,
    })
}

pub fn start_host_pairing(nodes: &HostedRunner) -> Result<Value, String> {
    nodes
        .hosting
        .device
        .run(&json!({ "command": "start_pairing" }))
}

pub fn join_and_approve(
    nodes: &HostedRunner,
    session: &Value,
    server_address: Option<String>,
) -> Result<(), String> {
    let mut join = json!({
        "command": "join_with_code",
        "code": read_text(session, "/display_code")?,
        "device_name": RUNNER_NAME,
        "role": "runner",
    });
    if let Some(server_address) = server_address {
        join["server_address"] = json!(server_address);
    }
    nodes.runner.run(&join)?;
    let request = nodes.hosting.device.run(&json!({
        "command": "pairing_request",
        "code": session["code"],
    }))?;
    let waiting = nodes.runner.run(&json!({ "command": "join_status" }))?;
    if request["joining"]["fingerprint_words"] != waiting["fingerprint_words"]
    {
        return Err("the two devices show different words".to_owned());
    }
    nodes.hosting.device.run(&json!({
        "command": "approve_pairing",
        "code": session["code"],
        "workspace_ids": [nodes.workspace_id],
    }))?;
    let status = nodes.runner.run(&json!({ "command": "join_status" }))?;
    if status["state"] != "approved" {
        return Err(format!("the join ended as {status}"));
    }
    Ok(())
}

pub fn run_a_task_to_done(nodes: &HostedRunner) -> Result<Value, String> {
    run_a_task_from(&nodes.hosting.device, &nodes.workspace_id)
}

pub fn run_a_task_from(
    client: &TestDevice,
    workspace_id: &str,
) -> Result<Value, String> {
    let project = client.run(&json!({
        "command": "create_project",
        "workspace_id": workspace_id,
        "name": "travel-app",
        "repositories": [{
            "address": LOCAL_REPOSITORY_ADDRESS,
            "default_branch": "main",
            "agent_access": "push_after_approval",
        }],
    }))?;
    let task = client.run(&json!({
        "command": "create_task",
        "start": "now",
        "task": {
            "workspace_id": workspace_id,
            "project_id": read_text(&project, "/id")?,
            "title": "Plan over the peer link",
            "details": PLAN_DETAILS,
            "doer": { "kind": "one_agent", "agent": "claude_code" },
            "runs_on": { "kind": "any_free_runner" },
            "agent_place": "local_process",
            "skills": [],
            "uses_automatic_skills": false,
            "approval_policy": "ask_before_risky_actions",
        },
    }))?;
    let runs = client.run(&json!({
        "command": "list_runs",
        "task_id": read_text(&task, "/id")?,
    }))?;
    let run_id = read_text(&runs, "/0/id")?;
    wait_for(FLOW_LIMIT, "the run to finish", || {
        let shown =
            client.run(&json!({ "command": "show_run", "run_id": run_id }))?;
        let status = &shown["run"]["status"];
        if status == "failed" || status == "cancelled" {
            return Err(format!("the run ended early: {}", shown["run"]));
        }
        Ok((status == "done").then_some(shown))
    })
}

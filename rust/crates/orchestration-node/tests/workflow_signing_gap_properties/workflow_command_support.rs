use serde_json::{Value, json};

use crate::command_builders::{PreparedWorkspace, prepare_workspace};

pub const START_ID: &str = "00000000-0000-0000-0000-000000000041";
pub const BUILD_ID: &str = "00000000-0000-0000-0000-000000000042";
const CHECK_ID: &str = "00000000-0000-0000-0000-000000000043";
const STEP_TASK: &str = "Do the work";
pub const OUTCOME_COUNT: usize = 2;

pub fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn step(agent_id: &str, name: &str) -> Value {
    json!({
        "id": agent_id,
        "name": name,
        "kind": "claude_code",
        "task": STEP_TASK,
        "runs_on": { "kind": "any_free_runner" },
        "skills": [],
        "uses_automatic_skills": false,
        "approval_policy": "never_ask",
        "position": { "horizontal": 0.0, "vertical": 0.0 },
    })
}

pub fn connection(from: &str, to: &str, outcome: Option<&str>) -> Value {
    json!({
        "from": from,
        "to": to,
        "condition": outcome,
        "round_limit": null,
    })
}

pub fn fork_connections(outcomes: &[String]) -> Vec<Value> {
    let targets = [BUILD_ID, CHECK_ID];
    let mut connections = Vec::new();
    for (target, outcome) in targets.iter().zip(outcomes) {
        connections.push(connection(START_ID, target, Some(outcome)));
    }
    connections
}

pub fn create_fork(
    prepared: &PreparedWorkspace,
    build_name: &str,
    connections: &[Value],
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "create_workflow",
        "workspace_id": prepared.workspace_id,
        "name": "release",
        "availability": { "kind": "all_workspaces" },
        "agents": [
            step(START_ID, "start"),
            step(BUILD_ID, build_name),
            step(CHECK_ID, "check"),
        ],
        "connections": connections,
    }))
}

pub fn list_workflows(
    prepared: &PreparedWorkspace,
) -> Result<Vec<Value>, String> {
    let listed = prepared.device.run(&json!({
        "command": "list_workflows",
        "workspace_id": prepared.workspace_id,
    }))?;
    Ok(listed.as_array().cloned().unwrap_or_default())
}

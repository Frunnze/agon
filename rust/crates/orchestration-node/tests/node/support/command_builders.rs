use serde_json::{Value, json};

use super::test_device::{TestDevice, read_text};
use super::test_server::TestServer;

pub const PROJECT_NAME: &str = "acme-app";
const PLAN_AGENT_ID: &str = "00000000-0000-0000-0000-000000000021";
const BUILD_AGENT_ID: &str = "00000000-0000-0000-0000-000000000022";

pub fn create_project_command(workspace_id: &str) -> Value {
    json!({
        "command": "create_project",
        "workspace_id": workspace_id,
        "name": PROJECT_NAME,
        "repositories": [{
            "address": "https://github.com/acme/app.git",
            "default_branch": "main",
            "agent_access": "push_after_approval",
        }],
    })
}

pub fn create_task_command(
    workspace_id: &str,
    project_id: &str,
    details: &str,
) -> Value {
    json!({
        "command": "create_task",
        "start": "later",
        "task": {
            "workspace_id": workspace_id,
            "project_id": project_id,
            "title": "Ship release 2.4",
            "details": details,
            "doer": { "kind": "one_agent", "agent": "claude_code" },
            "runs_on": { "kind": "any_free_runner" },
            "agent_place": "local_process",
            "skills": [],
            "uses_automatic_skills": true,
            "approval_policy": "ask_before_risky_actions",
        },
    })
}

pub fn create_skill_command(workspace_id: &str, instructions: &str) -> Value {
    json!({
        "command": "create_skill",
        "workspace_id": workspace_id,
        "name": "release-notes",
        "summary": "Write release notes",
        "instructions": instructions,
        "scope": everywhere_scope(),
        "usage": "automatic",
        "improvement": "never",
    })
}

pub fn create_rule_command(workspace_id: &str, details: &str) -> Value {
    json!({
        "command": "create_rule",
        "workspace_id": workspace_id,
        "title": "Never push to main",
        "details": details,
        "scope": everywhere_scope(),
    })
}

pub fn create_workflow_command(workspace_id: &str, agent_task: &str) -> Value {
    json!({
        "command": "create_workflow",
        "workspace_id": workspace_id,
        "name": "release",
        "availability": { "kind": "all_workspaces" },
        "agents": [{
            "id": "00000000-0000-0000-0000-000000000011",
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
    })
}

pub fn two_step_workflow_command(
    workspace_id: &str,
    plan_task: &str,
    build_task: &str,
) -> Value {
    json!({
        "command": "create_workflow",
        "workspace_id": workspace_id,
        "name": "release",
        "availability": { "kind": "all_workspaces" },
        "agents": [
            workflow_agent(PLAN_AGENT_ID, "plan", plan_task, "never_ask"),
            workflow_agent(
                BUILD_AGENT_ID,
                "build",
                build_task,
                "ask_before_risky_actions",
            ),
        ],
        "connections": [{ "from": PLAN_AGENT_ID, "to": BUILD_AGENT_ID }],
    })
}

fn workflow_agent(
    agent_id: &str,
    name: &str,
    task: &str,
    approval_policy: &str,
) -> Value {
    json!({
        "id": agent_id,
        "name": name,
        "kind": "claude_code",
        "task": task,
        "runs_on": { "kind": "any_free_runner" },
        "skills": [],
        "uses_automatic_skills": false,
        "approval_policy": approval_policy,
        "position": { "horizontal": 0.0, "vertical": 0.0 },
    })
}

fn everywhere_scope() -> Value {
    json!({
        "workspaces": { "kind": "all_workspaces" },
        "projects": { "kind": "all_projects" },
    })
}

#[derive(Debug)]
pub struct PreparedWorkspace {
    pub server: TestServer,
    pub device: TestDevice,
    pub workspace_id: String,
    pub project_id: String,
}

pub fn prepare_workspace() -> Result<PreparedWorkspace, String> {
    let server = TestServer::start()?;
    let device = TestDevice::start()?;
    let account = device.create_account(&server, "acme")?;
    let workspace_id = read_text(&account, "/workspaces/0/id")?;
    let project = device.run(&create_project_command(&workspace_id))?;
    let project_id = read_text(&project, "/id")?;
    Ok(PreparedWorkspace {
        server,
        device,
        workspace_id,
        project_id,
    })
}

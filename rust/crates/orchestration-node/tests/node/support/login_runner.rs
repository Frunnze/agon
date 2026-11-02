use std::fs;
use std::path::Path;
use std::time::Duration;

use serde_json::{Value, json};
use tempfile::TempDir;

use super::git_origin::{LOCAL_REPOSITORY_ADDRESS, create_local_origin};
use super::node_process::{NodeProcess, ProcessSetup};
use super::test_device::{describe, read_text};
use super::test_server::TestServer;
use super::waiting::wait_for;

const LOGIN_FIXTURES: &str =
    concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/login_bin");
const SYSTEM_SEARCH_PATH: &str = "/usr/bin:/bin:/usr/sbin:/sbin";
const SEARCH_PATH_VARIABLE: &str = "PATH";
const RECORDS_VARIABLE: &str = "AGENT_RECORDS";
const CONTAINER_RUNS_FILE_NAME: &str = "container-environment";
const RUN_SEPARATOR: &str = "--- run\n";
const LOGIN_LIMIT: Duration = Duration::from_secs(20);
const RUN_LIMIT: Duration = Duration::from_secs(120);
const RUNNING_STATE: &str = "running";
const PROJECT_NAME: &str = "travel-app";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ClaudePresence {
    Installed,
    Missing,
}

#[derive(Debug)]
pub struct LoginRunner {
    pub server: TestServer,
    pub runner: NodeProcess,
    pub workspace_id: String,
    pub records: TempDir,
    pub data: TempDir,
    project_id: Option<String>,
    _origin_root: TempDir,
}

#[must_use]
pub fn container_sandbox() -> Value {
    json!({
        "kind": "container",
        "engine": "docker",
        "image": "agents-orchestration-runner:latest",
        "allowed_hosts": [],
    })
}

#[must_use]
pub fn local_sandbox() -> Value {
    json!({ "kind": "local_process" })
}

fn choose_search_path(presence: ClaudePresence) -> Result<String, String> {
    match presence {
        ClaudePresence::Installed => {
            let inherited =
                std::env::var(SEARCH_PATH_VARIABLE).map_err(describe)?;
            Ok(format!("{LOGIN_FIXTURES}:{inherited}"))
        }
        ClaudePresence::Missing => Ok(SYSTEM_SEARCH_PATH.to_owned()),
    }
}

impl LoginRunner {
    pub fn start(
        sandbox: &Value,
        presence: ClaudePresence,
    ) -> Result<Self, String> {
        let server = TestServer::start()?;
        let records = TempDir::new().map_err(describe)?;
        let data = TempDir::new().map_err(describe)?;
        let origin_root = TempDir::new().map_err(describe)?;
        create_local_origin(origin_root.path())?;
        let clone_template =
            format!("file://{}/{{address}}", origin_root.path().display());
        let configuration = json!({
            "data_directory": data.path(),
            "identity_store": "file",
            "peer_relay": "disabled",
            "runner": {
                "labels": ["mac"],
                "slot_capacity": 1,
                "sandbox": sandbox,
                "clone_url_template": clone_template,
            },
        });
        let environment = [
            (SEARCH_PATH_VARIABLE, choose_search_path(presence)?),
            (RECORDS_VARIABLE, records.path().display().to_string()),
        ];
        let runner = NodeProcess::start(&ProcessSetup {
            configuration: &configuration,
            environment: &environment,
        })?;
        let account = runner.run(&json!({
            "command": "create_account",
            "server_address": server.address,
            "setup_code": server.read_setup_code()?,
            "device_name": "air-laptop",
            "role": "client_and_runner",
            "workspace_name": "acme",
        }))?;
        let workspace_id = read_text(&account, "/workspaces/0/id")?;
        Ok(Self {
            server,
            runner,
            workspace_id,
            records,
            data,
            project_id: None,
            _origin_root: origin_root,
        })
    }

    pub fn run(&self, command: &Value) -> Result<Value, String> {
        self.runner.run(command)
    }

    pub fn read_login_status(&self) -> Result<Value, String> {
        self.run(&json!({ "command": "agent_login_status" }))
    }

    pub fn wait_for_login_text(&self, expected: &str) -> Result<(), String> {
        wait_for(LOGIN_LIMIT, expected, || {
            let login = self.run(&json!({ "command": "read_agent_login" }))?;
            let lines = login["lines"].to_string();
            Ok(lines.contains(expected).then_some(()))
        })
    }

    pub fn wait_for_login_end(&self) -> Result<Value, String> {
        wait_for(LOGIN_LIMIT, "the login to end", || {
            let login = self.run(&json!({ "command": "read_agent_login" }))?;
            Ok((login["state"] != RUNNING_STATE).then_some(login))
        })
    }

    pub fn log_in_through_the_terminal(
        &self,
        place: &str,
        code: &str,
    ) -> Result<Value, String> {
        self.run(&json!({ "command": "start_agent_login", "place": place }))?;
        self.wait_for_login_text("Paste code here if prompted")?;
        self.run(&json!({
            "command": "type_agent_login",
            "keys": format!("{code}\r"),
        }))?;
        self.wait_for_login_end()
    }

    pub fn run_a_task_to_done(&mut self, title: &str) -> Result<(), String> {
        let project_id = self.find_or_create_project()?;
        let task = self.run(&json!({
            "command": "create_task",
            "start": "now",
            "task": {
                "workspace_id": self.workspace_id,
                "project_id": project_id,
                "title": title,
                "details": "Look around the repository.",
                "doer": { "kind": "one_agent", "agent": "claude_code" },
                "runs_on": { "kind": "any_free_runner" },
                "skills": [],
                "uses_automatic_skills": false,
                "approval_policy": "ask_before_risky_actions",
            },
        }))?;
        let runs = self.run(&json!({
            "command": "list_runs",
            "task_id": read_text(&task, "/id")?,
        }))?;
        let run_id = read_text(&runs, "/0/id")?;
        wait_for(RUN_LIMIT, "the run to finish", || {
            let shown = self.run(&json!({
                "command": "show_run",
                "run_id": run_id,
            }))?;
            let status = &shown["run"]["status"];
            if status == "failed" || status == "cancelled" {
                return Err(format!("the run ended early: {}", shown["run"]));
            }
            Ok((status == "done").then_some(()))
        })
    }

    pub fn read_container_runs(&self) -> Result<Vec<String>, String> {
        let path = self.records.path().join(CONTAINER_RUNS_FILE_NAME);
        let recorded = fs::read_to_string(path).map_err(describe)?;
        let runs = recorded
            .split(RUN_SEPARATOR)
            .filter(|run| !run.is_empty())
            .map(str::to_owned)
            .collect();
        Ok(runs)
    }

    fn find_or_create_project(&mut self) -> Result<String, String> {
        if let Some(project_id) = &self.project_id {
            return Ok(project_id.clone());
        }
        let project = self.run(&json!({
            "command": "create_project",
            "workspace_id": self.workspace_id,
            "name": PROJECT_NAME,
            "repositories": [{
                "address": LOCAL_REPOSITORY_ADDRESS,
                "default_branch": "main",
                "agent_access": "push_after_approval",
            }],
        }))?;
        let project_id = read_text(&project, "/id")?;
        self.project_id = Some(project_id.clone());
        Ok(project_id)
    }
}

pub fn find_text_in_folder(
    folder: &Path,
    needle: &str,
) -> Result<bool, String> {
    for entry in fs::read_dir(folder).map_err(describe)? {
        let entry_path = entry.map_err(describe)?.path();
        if entry_path.is_symlink() {
            continue;
        }
        if entry_path.is_dir() {
            if find_text_in_folder(&entry_path, needle)? {
                return Ok(true);
            }
            continue;
        }
        let file_bytes = fs::read(&entry_path).map_err(describe)?;
        if String::from_utf8_lossy(&file_bytes).contains(needle) {
            return Ok(true);
        }
    }
    Ok(false)
}

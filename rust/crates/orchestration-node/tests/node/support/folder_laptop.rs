use std::fs;
use std::path::{Path, PathBuf};

use serde_json::{Value, json};
use tempfile::TempDir;

use super::git_origin::run_git;
use super::node_process::{NodeProcess, ProcessSetup};
use super::test_device::{RELAY_DISABLED, describe, read_text};
use super::test_server::TestServer;

pub const LAPTOP_NAME: &str = "air-laptop";
pub const FOLDER_NAME: &str = "billing";
pub const FOLDER_README_TEXT: &str = "hello";
const FAKE_AGENT_FOLDER: &str =
    concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/bin");
const RECORDS_VARIABLE: &str = "AGENT_RECORDS";
const SEARCH_PATH_VARIABLE: &str = "PATH";

pub struct LaptopWithFolder {
    _server: TestServer,
    pub laptop: NodeProcess,
    pub workspace_id: String,
    pub records: TempDir,
    _data: TempDir,
    pub folder_parent: TempDir,
}

impl LaptopWithFolder {
    pub fn folder(&self) -> PathBuf {
        self.folder_parent.path().join(FOLDER_NAME)
    }

    pub fn create_folder_project(
        &self,
        agent_access: &str,
    ) -> Result<Value, String> {
        let checked = self.laptop.run(&json!({
            "command": "check_local_folder",
            "path": self.folder().display().to_string(),
        }))?;
        self.laptop.run(&json!({
            "command": "create_project",
            "workspace_id": self.workspace_id,
            "name": FOLDER_NAME,
            "repositories": [{
                "address": checked["address"],
                "default_branch": checked["default_branch"],
                "agent_access": agent_access,
            }],
        }))
    }

    pub fn start_folder_task(
        &self,
        project_id: &str,
        title: &str,
    ) -> Result<String, String> {
        let task = self.laptop.run(&json!({
            "command": "create_task",
            "start": "now",
            "task": {
                "workspace_id": self.workspace_id,
                "project_id": project_id,
                "title": title,
                "details": format!("{title} in the folder"),
                "doer": { "kind": "one_agent", "agent": "claude_code" },
                "runs_on": { "kind": "any_free_runner" },
                "agent_place": "local_process",
                "skills": [],
                "uses_automatic_skills": false,
                "approval_policy": "never_ask",
            },
        }))?;
        let runs = self.laptop.run(&json!({
            "command": "list_runs",
            "task_id": read_text(&task, "/id")?,
        }))?;
        read_text(&runs, "/0/id")
    }
}

fn start_laptop(data: &Path, records: &Path) -> Result<NodeProcess, String> {
    let configuration = json!({
        "data_directory": data,
        "identity_store": "file",
        "peer_relay": RELAY_DISABLED,
        "runner": {
            "labels": ["mac"],
            "slot_capacity": 1,
            "sandbox": { "kind": "local_process" },
        },
    });
    let inherited_path =
        std::env::var(SEARCH_PATH_VARIABLE).map_err(describe)?;
    let environment = [
        (
            SEARCH_PATH_VARIABLE,
            format!("{FAKE_AGENT_FOLDER}:{inherited_path}"),
        ),
        (RECORDS_VARIABLE, records.display().to_string()),
    ];
    NodeProcess::start(&ProcessSetup {
        configuration: &configuration,
        environment: &environment,
    })
}

fn create_account(
    laptop: &NodeProcess,
    server: &TestServer,
) -> Result<Value, String> {
    laptop.run(&json!({
        "command": "create_account",
        "server_address": server.address,
        "setup_code": server.read_setup_code()?,
        "device_name": LAPTOP_NAME,
        "role": "client_and_runner",
        "workspace_name": "acme",
    }))
}

fn create_folder(parent: &Path) -> Result<(), String> {
    let folder = parent.join(FOLDER_NAME);
    fs::create_dir_all(&folder).map_err(describe)?;
    run_git(&folder, &["init", "--quiet", "--initial-branch=main"])?;
    fs::write(folder.join("README.md"), FOLDER_README_TEXT)
        .map_err(describe)?;
    run_git(&folder, &["add", "--all"])?;
    run_git(&folder, &["commit", "--quiet", "--message", "Start"])?;
    Ok(())
}

pub fn start_laptop_with_folder() -> Result<LaptopWithFolder, String> {
    let server = TestServer::start()?;
    let data = TempDir::new().map_err(describe)?;
    let records = TempDir::new().map_err(describe)?;
    let laptop = start_laptop(data.path(), records.path())?;
    let account = create_account(&laptop, &server)?;
    let workspace_id = read_text(&account, "/workspaces/0/id")?;
    let folder_parent = TempDir::new().map_err(describe)?;
    create_folder(folder_parent.path())?;
    Ok(LaptopWithFolder {
        _server: server,
        laptop,
        workspace_id,
        records,
        _data: data,
        folder_parent,
    })
}

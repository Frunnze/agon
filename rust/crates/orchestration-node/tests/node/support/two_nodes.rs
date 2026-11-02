use std::path::Path;

use serde_json::json;
use tempfile::TempDir;

use super::git_origin::create_local_origin;
use super::node_process::{NodeProcess, ProcessSetup};
use super::test_device::{RELAY_DISABLED, TestDevice, describe, read_text};
use super::test_server::TestServer;

const FAKE_AGENT_FOLDER: &str =
    concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/bin");
const RECORDS_VARIABLE: &str = "AGENT_RECORDS";
const SEARCH_PATH_VARIABLE: &str = "PATH";
const RUNNER_NAME: &str = "office-runner";

#[derive(Debug)]
pub struct TwoNodes {
    pub server: TestServer,
    pub client: TestDevice,
    pub runner: NodeProcess,
    pub workspace_id: String,
    pub records: TempDir,
    pub origin_root: TempDir,
    pub runner_data: TempDir,
}

#[derive(Clone, Copy, Debug)]
pub struct RunnerFolders<'folders> {
    pub runner_data: &'folders Path,
    pub origin_root: &'folders Path,
    pub records: &'folders Path,
}

pub fn start_runner_process(
    folders: RunnerFolders<'_>,
    peer_relay: &str,
) -> Result<NodeProcess, String> {
    let RunnerFolders {
        runner_data,
        origin_root,
        records,
    } = folders;
    let clone_template =
        format!("file://{}/{{address}}", origin_root.display());
    let configuration = json!({
        "data_directory": runner_data,
        "identity_store": "file",
        "peer_relay": peer_relay,
        "runner": {
            "labels": ["mac"],
            "slot_capacity": 1,
            "sandbox": { "kind": "local_process" },
            "clone_url_template": clone_template,
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

fn pair_runner(nodes: &TwoNodes) -> Result<(), String> {
    let session = nodes.client.run(&json!({ "command": "start_pairing" }))?;
    nodes.runner.run(&json!({
        "command": "join_with_code",
        "server_address": nodes.server.address,
        "code": read_text(&session, "/display_code")?,
        "device_name": RUNNER_NAME,
        "role": "runner",
    }))?;
    let request = nodes.client.run(&json!({
        "command": "pairing_request",
        "code": session["code"],
    }))?;
    let waiting = nodes.runner.run(&json!({ "command": "join_status" }))?;
    if request["joining"]["fingerprint_words"] != waiting["fingerprint_words"]
    {
        return Err("the two devices show different words".to_owned());
    }
    nodes.client.run(&json!({
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

fn start_two_nodes() -> Result<TwoNodes, String> {
    let server = TestServer::start()?;
    let client = TestDevice::start()?;
    let account = client.create_account(&server, "acme")?;
    let workspace_id = read_text(&account, "/workspaces/0/id")?;
    let origin_root = TempDir::new().map_err(describe)?;
    create_local_origin(origin_root.path())?;
    let records = TempDir::new().map_err(describe)?;
    let runner_data = TempDir::new().map_err(describe)?;
    let folders = RunnerFolders {
        runner_data: runner_data.path(),
        origin_root: origin_root.path(),
        records: records.path(),
    };
    let runner = start_runner_process(folders, RELAY_DISABLED)?;
    let nodes = TwoNodes {
        server,
        client,
        runner,
        workspace_id,
        records,
        origin_root,
        runner_data,
    };
    pair_runner(&nodes)?;
    Ok(nodes)
}

pub fn start_two_nodes_or_panic() -> TwoNodes {
    match start_two_nodes() {
        Ok(nodes) => nodes,
        Err(message) => panic!("the two nodes start and pair: {message}"),
    }
}

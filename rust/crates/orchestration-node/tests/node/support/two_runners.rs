use std::path::Path;

use tempfile::TempDir;

use super::git_origin::create_local_origin;
use super::node_process::NodeProcess;
use super::test_device::{RELAY_DISABLED, TestDevice, describe, read_text};
use super::test_server::TestServer;
use super::two_nodes::{
    RunnerFolders, RunnerJoin, pair_runner, start_runner_process,
};

pub const FIRST_RUNNER_NAME: &str = "office-runner";
pub const SECOND_RUNNER_NAME: &str = "studio-runner";

#[derive(Debug)]
pub struct PairedRunner {
    _process: NodeProcess,
    pub device_id: String,
    _data: TempDir,
}

#[derive(Debug)]
pub struct TwoRunners {
    _server: TestServer,
    pub client: TestDevice,
    pub first: PairedRunner,
    pub second: PairedRunner,
    pub workspace_id: String,
    _records: TempDir,
    _origin_root: TempDir,
}

struct RunnerSetting<'setting> {
    server: &'setting TestServer,
    client: &'setting TestDevice,
    workspace_id: &'setting str,
    origin_root: &'setting Path,
    records: &'setting Path,
}

fn start_paired_runner(
    setting: &RunnerSetting<'_>,
    device_name: &str,
) -> Result<PairedRunner, String> {
    let data = TempDir::new().map_err(describe)?;
    let folders = RunnerFolders {
        runner_data: data.path(),
        origin_root: setting.origin_root,
        records: setting.records,
    };
    let process = start_runner_process(folders, RELAY_DISABLED)?;
    let device_id = pair_runner(RunnerJoin {
        server_address: &setting.server.address,
        client: setting.client,
        runner: &process,
        workspace_id: setting.workspace_id,
        device_name,
    })?;
    Ok(PairedRunner {
        _process: process,
        device_id,
        _data: data,
    })
}

pub fn start_two_runners() -> Result<TwoRunners, String> {
    let server = TestServer::start()?;
    let client = TestDevice::start()?;
    let account = client.create_account(&server, "acme")?;
    let workspace_id = read_text(&account, "/workspaces/0/id")?;
    let origin_root = TempDir::new().map_err(describe)?;
    create_local_origin(origin_root.path())?;
    let records = TempDir::new().map_err(describe)?;

    let setting = RunnerSetting {
        server: &server,
        client: &client,
        workspace_id: &workspace_id,
        origin_root: origin_root.path(),
        records: records.path(),
    };
    let first = start_paired_runner(&setting, FIRST_RUNNER_NAME)?;
    let second = start_paired_runner(&setting, SECOND_RUNNER_NAME)?;

    Ok(TwoRunners {
        _server: server,
        client,
        first,
        second,
        workspace_id,
        _records: records,
        _origin_root: origin_root,
    })
}

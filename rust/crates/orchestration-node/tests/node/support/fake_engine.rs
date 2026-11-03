use std::fs;

use serde_json::{Value, json};
use tempfile::TempDir;

use super::node_process::{EnvironmentVariable, NodeProcess, ProcessSetup};
use super::test_device::describe;
use super::test_server::TestServer;

const SEARCH_PATH_VARIABLE: &str = "PATH";
const ENGINE_FILE_NAME: &str = "docker";
const EXECUTABLE_MODE: u32 = 0o755;
const HEARTBEAT_PATH: &str = "/runners/heartbeat";
const CLAIM_PATH: &str = "/runners/claim";
const OLDER_PLACE_FILE_NAME: &str = "agent-place.json";
pub const DEFAULT_IMAGE: &str = "agents-orchestration-runner:latest";

#[derive(Clone, Copy, Debug)]
pub struct EngineAnswers {
    pub info_exit_code: u8,
    pub image_exit_code: u8,
}

#[derive(Debug)]
pub struct EngineRunner {
    pub server: TestServer,
    pub runner: NodeProcess,
    configuration: Value,
    environment: Vec<EnvironmentVariable>,
    _engine_folder: TempDir,
    data: TempDir,
}

#[must_use]
pub fn container_sandbox() -> Value {
    json!({
        "kind": "container",
        "engine": "docker",
        "image": DEFAULT_IMAGE,
        "allowed_hosts": [],
    })
}

#[must_use]
pub fn local_sandbox() -> Value {
    json!({ "kind": "local_process" })
}

fn write_fake_engine(
    folder: &TempDir,
    answers: EngineAnswers,
) -> Result<(), String> {
    let script = format!(
        "#!/bin/sh\ncase \"$1\" in\n  info) exit {};;\nesac\nexit {}\n",
        answers.info_exit_code, answers.image_exit_code
    );
    let engine_path = folder.path().join(ENGINE_FILE_NAME);
    fs::write(&engine_path, script).map_err(describe)?;
    let mut permissions =
        fs::metadata(&engine_path).map_err(describe)?.permissions();
    std::os::unix::fs::PermissionsExt::set_mode(
        &mut permissions,
        EXECUTABLE_MODE,
    );
    fs::set_permissions(&engine_path, permissions).map_err(describe)
}

impl EngineRunner {
    pub fn start(
        sandbox: &Value,
        answers: EngineAnswers,
    ) -> Result<Self, String> {
        let server = TestServer::start()?;
        let engine_folder = TempDir::new().map_err(describe)?;
        write_fake_engine(&engine_folder, answers)?;
        let data = TempDir::new().map_err(describe)?;
        let inherited_path =
            std::env::var(SEARCH_PATH_VARIABLE).map_err(describe)?;
        let search_path =
            format!("{}:{inherited_path}", engine_folder.path().display());
        let configuration = json!({
            "data_directory": data.path(),
            "identity_store": "file",
            "peer_relay": "disabled",
            "runner": {
                "labels": ["linux"],
                "slot_capacity": 1,
                "sandbox": sandbox,
            },
        });
        let environment = vec![(SEARCH_PATH_VARIABLE, search_path)];
        let runner = NodeProcess::start(&ProcessSetup {
            configuration: &configuration,
            environment: &environment,
        })?;
        runner.run(&json!({
            "command": "create_account",
            "server_address": server.address,
            "setup_code": server.read_setup_code()?,
            "device_name": "build-box",
            "role": "client_and_runner",
            "workspace_name": "acme",
        }))?;
        Ok(Self {
            server,
            runner,
            configuration,
            environment,
            _engine_folder: engine_folder,
            data,
        })
    }

    pub fn restart(self) -> Result<Self, String> {
        let Self {
            server,
            runner,
            configuration,
            environment,
            _engine_folder: engine_folder,
            data,
        } = self;
        runner.stop()?;
        let fresh_runner = NodeProcess::start(&ProcessSetup {
            configuration: &configuration,
            environment: &environment,
        })?;
        Ok(Self {
            server,
            runner: fresh_runner,
            configuration,
            environment,
            _engine_folder: engine_folder,
            data,
        })
    }

    #[must_use]
    pub fn count_runner_requests(&self) -> usize {
        self.server
            .recorded_requests()
            .iter()
            .filter(|request| {
                request.path == HEARTBEAT_PATH || request.path == CLAIM_PATH
            })
            .count()
    }

    #[must_use]
    pub fn read_status(&self) -> Value {
        self.runner
            .run(&json!({ "command": "status" }))
            .unwrap_or(Value::Null)
    }

    pub fn list_runners(&self) -> Result<Value, String> {
        self.runner.run(&json!({
            "command": "list_runners",
            "workspace_id": "00000000-0000-0000-0000-000000000000",
        }))
    }

    pub fn choose_offers(&self, offers: &Value) -> Result<Value, String> {
        self.runner.run(&json!({
            "command": "choose_agent_offers",
            "offers": offers,
        }))
    }

    pub fn write_older_place_choice(&self, place: &str) -> Result<(), String> {
        let older_file = self.data.path().join(OLDER_PLACE_FILE_NAME);
        fs::write(older_file, json!(place).to_string()).map_err(describe)
    }

    #[must_use]
    pub fn read_last_heartbeat_offers(&self) -> Option<Value> {
        let heartbeat = self
            .server
            .recorded_requests()
            .into_iter()
            .rfind(|request| request.path == HEARTBEAT_PATH)?;
        let body: Value = serde_json::from_slice(&heartbeat.body).ok()?;
        Some(body["offers"].clone())
    }
}

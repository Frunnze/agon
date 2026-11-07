use std::fmt::Display;
use std::sync::Arc;

use orchestration_node::identity_store::{FileIdentityStore, IdentityStore};
use orchestration_node::node::Node;
use orchestration_node::node_configuration::{
    DEFAULT_APP_SERVER_PORT, DEFAULT_TAKEOVER_SECONDS, IdentityStoreChoice,
    NodeConfiguration, PeerRelayChoice,
};
use orchestration_node::node_runtime::NodeRuntime;
use orchestration_node::runner_bridge::NodeRunnerServer;
use orchestration_security::identity::DeviceIdentity;
use proptest::test_runner::TestCaseError;
use serde_json::{Value, json};
use tempfile::TempDir;

use super::test_server::TestServer;

pub const UNREACHABLE_SERVER_ADDRESS: &str = "http://127.0.0.1:9";
pub const RELAY_DISABLED: &str = "disabled";
pub const RELAY_DEFAULT: &str = "default";
const RUNNER_OFF: &str = "off";
pub const DEFAULT_DEVICE_ROLE: &str = "client_and_runner";
const IDENTITY_FILE_NAME: &str = "device-identity.key";

#[derive(Debug)]
pub struct TestDevice {
    pub runtime: NodeRuntime,
    pub data_directory: TempDir,
    configuration: Value,
}

impl TestDevice {
    pub fn start() -> Result<Self, String> {
        Self::start_with_runner(Some(json!(RUNNER_OFF)))
    }

    pub fn start_runner(runner_settings: &Value) -> Result<Self, String> {
        Self::start_with_runner(Some(runner_settings.clone()))
    }

    pub fn start_detecting_runner() -> Result<Self, String> {
        Self::start_with_runner(None)
    }

    pub fn restart(&mut self) -> Result<(), String> {
        let configuration = self.configuration.to_string();
        let fresh_runtime =
            NodeRuntime::start(&configuration).map_err(describe)?;
        let stopped_runtime =
            std::mem::replace(&mut self.runtime, fresh_runtime);
        drop(stopped_runtime);
        Ok(())
    }

    pub fn start_hosting_on(app_server_port: u16) -> Result<Self, String> {
        Self::start_hosting(app_server_port, RELAY_DISABLED)
    }

    pub fn start_hosting(
        app_server_port: u16,
        peer_relay: &str,
    ) -> Result<Self, String> {
        let data_directory = TempDir::new().map_err(describe)?;
        let configuration = json!({
            "data_directory": data_directory.path(),
            "identity_store": "file",
            "peer_relay": peer_relay,
            "runner": RUNNER_OFF,
            "app_server_port": app_server_port,
        });
        Self::start_with(data_directory, configuration)
    }

    pub fn start_crossing_networks() -> Result<Self, String> {
        let data_directory = TempDir::new().map_err(describe)?;
        let configuration = json!({
            "data_directory": data_directory.path(),
            "identity_store": "file",
            "peer_relay": RELAY_DEFAULT,
            "runner": RUNNER_OFF,
        });
        Self::start_with(data_directory, configuration)
    }

    pub fn start_keeping(
        app_server_port: u16,
        takeover_seconds: u64,
    ) -> Result<Self, String> {
        let data_directory = TempDir::new().map_err(describe)?;
        let configuration = json!({
            "data_directory": data_directory.path(),
            "identity_store": "file",
            "peer_relay": RELAY_DISABLED,
            "runner": RUNNER_OFF,
            "app_server_port": app_server_port,
            "server_takeover_seconds": takeover_seconds,
        });
        Self::start_with(data_directory, configuration)
    }

    pub fn stop(self) -> StoppedDevice {
        let Self {
            runtime,
            data_directory,
            configuration,
        } = self;
        drop(runtime);
        StoppedDevice {
            data_directory,
            configuration,
        }
    }

    pub fn stop_and_start_again(self) -> Result<Self, String> {
        let Self {
            runtime,
            data_directory,
            configuration,
        } = self;
        drop(runtime);
        Self::start_with(data_directory, configuration)
    }

    fn start_with_runner(runner: Option<Value>) -> Result<Self, String> {
        let data_directory = TempDir::new().map_err(describe)?;
        let mut configuration = json!({
            "data_directory": data_directory.path(),
            "identity_store": "file",
            "peer_relay": RELAY_DISABLED,
        });
        if let Some(runner) = runner {
            configuration["runner"] = runner;
        }
        Self::start_with(data_directory, configuration)
    }

    fn start_with(
        data_directory: TempDir,
        configuration: Value,
    ) -> Result<Self, String> {
        let runtime = NodeRuntime::start(&configuration.to_string())
            .map_err(describe)?;
        Ok(Self {
            runtime,
            data_directory,
            configuration,
        })
    }

    pub fn open_runner_server(&self) -> Result<NodeRunnerServer, String> {
        let configuration = NodeConfiguration {
            data_directory: self.data_directory.path().to_path_buf(),
            identity_store: IdentityStoreChoice::File,
            runner: None,
            peer_relay: PeerRelayChoice::Disabled,
            app_server_port: DEFAULT_APP_SERVER_PORT,
            server_takeover_seconds: DEFAULT_TAKEOVER_SECONDS,
        };
        let node = Node::open(&configuration).map_err(describe)?;
        Ok(NodeRunnerServer::new(Arc::new(node)))
    }

    pub fn send(&self, command: &Value) -> Value {
        let reply_text = self.runtime.handle_command(&command.to_string());
        serde_json::from_str(&reply_text).unwrap_or(Value::Null)
    }

    pub fn run(&self, command: &Value) -> Result<Value, String> {
        read_success(&self.send(command))
    }

    pub fn create_account(
        &self,
        server: &TestServer,
        workspace_name: &str,
    ) -> Result<Value, String> {
        self.create_account_with_role(
            server,
            workspace_name,
            DEFAULT_DEVICE_ROLE,
        )
    }

    pub fn create_account_with_role(
        &self,
        server: &TestServer,
        workspace_name: &str,
        role: &str,
    ) -> Result<Value, String> {
        self.run(&serde_json::json!({
            "command": "create_account",
            "server_address": server.address,
            "setup_code": server.read_setup_code()?,
            "device_name": "air-laptop",
            "role": role,
            "workspace_name": workspace_name,
        }))
    }

    pub fn load_identity(&self) -> Result<DeviceIdentity, String> {
        let identity_path =
            self.data_directory.path().join(IDENTITY_FILE_NAME);
        let store = FileIdentityStore::new(identity_path);
        let identity = store.load_identity().map_err(describe)?;
        identity.ok_or_else(|| "the device has no identity".to_owned())
    }
}

#[derive(Debug)]
pub struct StoppedDevice {
    data_directory: TempDir,
    configuration: Value,
}

impl StoppedDevice {
    pub fn start_again(self) -> Result<TestDevice, String> {
        TestDevice::start_with(self.data_directory, self.configuration)
    }
}

pub fn read_success(reply: &Value) -> Result<Value, String> {
    if let Some(success) = reply.get("ok") {
        return Ok(success.clone());
    }
    let message = reply.get("error").and_then(Value::as_str);
    Err(message
        .unwrap_or("the reply has neither ok nor error")
        .into())
}

pub fn describe(error: impl Display) -> String {
    error.to_string()
}

pub fn fail(error: impl Display) -> TestCaseError {
    TestCaseError::fail(error.to_string())
}

pub fn read_text(value: &Value, pointer: &str) -> Result<String, String> {
    let found = value.pointer(pointer).and_then(Value::as_str);
    let text = found.ok_or_else(|| format!("{pointer} is missing"))?;
    Ok(text.to_owned())
}

pub fn is_defined_reply(reply: &Value) -> bool {
    let Some(fields) = reply.as_object() else {
        return false;
    };
    let has_success = fields.contains_key("ok");
    let has_error = fields.get("error").is_some_and(Value::is_string);
    let has_kind = fields.get("error_kind").is_some_and(Value::is_string);
    let kind_field_count = usize::from(has_error && has_kind);
    fields.len() == 1 + kind_field_count && (has_success || has_error)
}

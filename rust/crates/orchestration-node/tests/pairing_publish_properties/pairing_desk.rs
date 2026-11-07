use std::fmt::Display;
use std::fs;
use std::sync::Arc;
use std::time::Duration;

use orchestration_node::commands::dispatch_command;
use orchestration_node::node::Node;
use orchestration_node::node_configuration::{
    DEFAULT_APP_SERVER_PORT, DEFAULT_TAKEOVER_SECONDS, IdentityStoreChoice,
    NodeConfiguration, PeerRelayChoice,
};
use orchestration_node::node_runtime::NodeRuntime;
use orchestration_server::{
    Clock, Server, ServerSettings, SystemClock, serve_app_server,
};
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde_json::{Value, json};
use tempfile::TempDir;
use tokio::net::TcpListener;
use tokio::runtime::Runtime;

pub const PUBLISH_CASES: u32 = 4;
pub const RENDEZVOUS_PROBLEM_FIELD: &str = "rendezvous_problem";
pub const NO_PEER_ENDPOINT: &str = "this node has no peer endpoint";
const MAXIMUM_ACTIONS: usize = 5;
const LOOPBACK_ADDRESS: &str = "127.0.0.1:0";
const ADDRESS_SCHEME: &str = "http://";
const LONG_POLL_TIMEOUT: Duration = Duration::from_millis(50);
const SETUP_CODE_FILE_NAME: &str = "setup-code";
const RELAY_DISABLED: &str = "disabled";
const RUNNER_OFF: &str = "off";

#[derive(Clone, Copy, Debug)]
pub enum PairingAction {
    Start,
    CancelLatest,
}

pub trait PairingDevice {
    fn run(&self, command: &Value) -> Result<Value, String>;
}

#[derive(Debug)]
pub struct LocalAppServer {
    _serving_runtime: Runtime,
    address: String,
    data_directory: TempDir,
}

#[derive(Debug)]
pub struct BareDevice {
    runtime: Runtime,
    node: Node,
    _data_directory: TempDir,
}

#[derive(Debug)]
pub struct RuntimeDevice {
    runtime: NodeRuntime,
    _data_directory: TempDir,
}

pub fn pairing_actions() -> impl Strategy<Value = Vec<PairingAction>> {
    let action = prop_oneof![
        Just(PairingAction::Start),
        Just(PairingAction::CancelLatest),
    ];
    proptest::collection::vec(action, 1..=MAXIMUM_ACTIONS)
}

pub fn peer_relay_choices() -> impl Strategy<Value = PeerRelayChoice> {
    prop_oneof![
        Just(PeerRelayChoice::Disabled),
        Just(PeerRelayChoice::Default),
    ]
}

impl LocalAppServer {
    pub fn start() -> Result<Self, String> {
        let runtime = build_runtime()?;
        let data_directory = TempDir::new().map_err(describe)?;
        let listener = runtime
            .block_on(TcpListener::bind(LOOPBACK_ADDRESS))
            .map_err(describe)?;
        let local_address = listener.local_addr().map_err(describe)?;
        let address = format!("{ADDRESS_SCHEME}{local_address}");

        let settings = ServerSettings {
            data_directory: data_directory.path().to_path_buf(),
            public_address: address.clone(),
            long_poll_timeout: LONG_POLL_TIMEOUT,
        };
        let clock: Arc<dyn Clock> = Arc::new(SystemClock);
        let server = Server::open(settings, clock).map_err(describe)?;
        runtime.spawn(serve_app_server(listener, Arc::new(server)));
        Ok(Self {
            _serving_runtime: runtime,
            address,
            data_directory,
        })
    }

    fn build_create_account_command(&self) -> Result<Value, String> {
        let setup_code_path =
            self.data_directory.path().join(SETUP_CODE_FILE_NAME);
        let setup_code =
            fs::read_to_string(setup_code_path).map_err(describe)?;
        Ok(json!({
            "command": "create_account",
            "server_address": self.address,
            "setup_code": setup_code.trim(),
            "device_name": "air-laptop",
            "role": "client_and_runner",
            "workspace_name": "acme",
        }))
    }
}

impl BareDevice {
    pub fn open_with_account(
        server: &LocalAppServer,
        peer_relay: PeerRelayChoice,
    ) -> Result<Self, String> {
        let data_directory = TempDir::new().map_err(describe)?;
        let configuration = NodeConfiguration {
            data_directory: data_directory.path().to_path_buf(),
            identity_store: IdentityStoreChoice::File,
            runner: None,
            peer_relay,
            app_server_port: DEFAULT_APP_SERVER_PORT,
            server_takeover_seconds: DEFAULT_TAKEOVER_SECONDS,
        };
        let device = Self {
            runtime: build_runtime()?,
            node: Node::open(&configuration).map_err(describe)?,
            _data_directory: data_directory,
        };
        device.run(&server.build_create_account_command()?)?;
        Ok(device)
    }
}

impl PairingDevice for BareDevice {
    fn run(&self, command: &Value) -> Result<Value, String> {
        let command_text = command.to_string();
        let reply_text = self
            .runtime
            .block_on(dispatch_command(&self.node, &command_text));
        read_success(&reply_text)
    }
}

impl RuntimeDevice {
    pub fn start_local_only_with_account(
        server: &LocalAppServer,
    ) -> Result<Self, String> {
        let data_directory = TempDir::new().map_err(describe)?;
        let configuration = json!({
            "data_directory": data_directory.path(),
            "identity_store": "file",
            "peer_relay": RELAY_DISABLED,
            "runner": RUNNER_OFF,
        });
        let runtime = NodeRuntime::start(&configuration.to_string())
            .map_err(describe)?;
        let device = Self {
            runtime,
            _data_directory: data_directory,
        };
        device.run(&server.build_create_account_command()?)?;
        Ok(device)
    }
}

impl PairingDevice for RuntimeDevice {
    fn run(&self, command: &Value) -> Result<Value, String> {
        let reply_text = self.runtime.handle_command(&command.to_string());
        read_success(&reply_text)
    }
}

pub fn start_pairing(device: &dyn PairingDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "start_pairing" }))
}

pub fn cancel_pairing(
    device: &dyn PairingDevice,
    session: &Value,
) -> Result<Value, String> {
    device.run(&json!({
        "command": "cancel_pairing",
        "code": session["code"],
    }))
}

pub fn read_status_problem(
    device: &dyn PairingDevice,
) -> Result<Value, String> {
    let status = device.run(&json!({ "command": "status" }))?;
    read_reply_problem(&status)
}

pub fn read_reply_problem(reply: &Value) -> Result<Value, String> {
    let problem = reply.get(RENDEZVOUS_PROBLEM_FIELD).cloned();
    problem.ok_or_else(|| format!("{RENDEZVOUS_PROBLEM_FIELD} is missing"))
}

pub fn read_success(reply_text: &str) -> Result<Value, String> {
    let reply: Value = serde_json::from_str(reply_text).map_err(describe)?;
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

fn build_runtime() -> Result<Runtime, String> {
    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .map_err(describe)
}

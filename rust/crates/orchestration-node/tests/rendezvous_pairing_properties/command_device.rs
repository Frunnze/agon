use orchestration_node::commands::dispatch_command;
use orchestration_node::node::Node;
use orchestration_node::node_configuration::{
    DEFAULT_APP_SERVER_PORT, DEFAULT_TAKEOVER_SECONDS, IdentityStoreChoice,
    NodeConfiguration, PeerRelayChoice,
};
use proptest::prelude::*;
use serde_json::Value;
use tempfile::TempDir;
use tokio::runtime::Runtime;

use crate::support::test_device::{TestDevice, describe, read_success};

const LOCAL_RELAY_ADDRESS: &str = "http://127.0.0.1:9";

pub trait CommandDevice: Sync {
    fn run(&self, command: &Value) -> Result<Value, String>;
}

#[derive(Debug)]
pub struct BareNode {
    runtime: Runtime,
    node: Node,
    _data_directory: TempDir,
}

impl BareNode {
    pub fn open(peer_relay: PeerRelayChoice) -> Result<Self, String> {
        let data_directory = TempDir::new().map_err(describe)?;
        let configuration = NodeConfiguration {
            data_directory: data_directory.path().to_path_buf(),
            identity_store: IdentityStoreChoice::File,
            runner: None,
            peer_relay,
            app_server_port: DEFAULT_APP_SERVER_PORT,
            server_takeover_seconds: DEFAULT_TAKEOVER_SECONDS,
        };
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(describe)?;
        let node = Node::open(&configuration).map_err(describe)?;
        Ok(Self {
            runtime,
            node,
            _data_directory: data_directory,
        })
    }
}

impl CommandDevice for BareNode {
    fn run(&self, command: &Value) -> Result<Value, String> {
        let command_text = command.to_string();
        let dispatching = dispatch_command(&self.node, &command_text);
        let reply_text = self.runtime.block_on(dispatching);
        let reply: Value =
            serde_json::from_str(&reply_text).map_err(describe)?;
        read_success(&reply)
    }
}

impl CommandDevice for TestDevice {
    fn run(&self, command: &Value) -> Result<Value, String> {
        read_success(&self.send(command))
    }
}

pub fn crossing_relay_choices() -> impl Strategy<Value = PeerRelayChoice> {
    prop_oneof![
        Just(PeerRelayChoice::Default),
        Just(PeerRelayChoice::Custom(LOCAL_RELAY_ADDRESS.to_owned())),
    ]
}

pub fn every_relay_choice() -> impl Strategy<Value = PeerRelayChoice> {
    prop_oneof![Just(PeerRelayChoice::Disabled), crossing_relay_choices()]
}

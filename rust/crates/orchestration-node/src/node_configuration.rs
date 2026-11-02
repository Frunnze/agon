use std::path::PathBuf;

use orchestration_p2p::peer_configuration::RelayChoice;
use serde::Deserialize;

use crate::node_error::NodeError;
use crate::runner_settings::RunnerChoice;

pub const DEFAULT_APP_SERVER_PORT: u16 = 8731;
pub const DEFAULT_TAKEOVER_SECONDS: u64 = 30;

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum IdentityStoreChoice {
    Keychain,
    File,
    EncryptedFile { key: String },
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PeerRelayChoice {
    #[default]
    Default,
    Disabled,
    Custom(String),
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct NodeConfiguration {
    pub data_directory: PathBuf,
    pub identity_store: IdentityStoreChoice,
    pub runner: Option<RunnerChoice>,
    #[serde(default)]
    pub peer_relay: PeerRelayChoice,
    #[serde(default = "choose_default_app_server_port")]
    pub app_server_port: u16,
    #[serde(default = "choose_default_takeover_seconds")]
    pub server_takeover_seconds: u64,
}

impl PeerRelayChoice {
    pub(crate) fn to_relay_choice(&self) -> RelayChoice {
        match self {
            Self::Default => RelayChoice::Default,
            Self::Disabled => RelayChoice::Disabled,
            Self::Custom(relay_url) => RelayChoice::Custom(relay_url.clone()),
        }
    }
}

fn choose_default_app_server_port() -> u16 {
    DEFAULT_APP_SERVER_PORT
}

fn choose_default_takeover_seconds() -> u64 {
    DEFAULT_TAKEOVER_SECONDS
}

impl NodeConfiguration {
    pub fn from_json(configuration_json: &str) -> Result<Self, NodeError> {
        serde_json::from_str(configuration_json).map_err(|error| {
            NodeError::Startup(format!("invalid configuration: {error}"))
        })
    }
}

use std::time::Duration;

use orchestration_core::peer_address::PeerAddress;
use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::peer_connection::PeerConnection;
use orchestration_p2p::service_endpoint::{
    APP_SERVER_PROTOCOL_NAME, ServiceEndpoint,
};
use orchestration_security::peer_addresses::generate_peer_secret;
use tokio::sync::OnceCell;
use tokio::time::timeout;

use crate::node_error::NodeError;

pub const PEER_CONNECT_LIMIT: Duration = Duration::from_secs(10);
const LATE_CONNECTION: &str = "the app server did not accept in time";

#[derive(Debug)]
pub struct PeerDialer {
    relay: RelayChoice,
    endpoint: OnceCell<ServiceEndpoint>,
}

impl PeerDialer {
    #[must_use]
    pub fn new(relay: RelayChoice) -> Self {
        Self {
            relay,
            endpoint: OnceCell::new(),
        }
    }

    pub(super) async fn connect(
        &self,
        server: &PeerAddress,
    ) -> Result<PeerConnection, NodeError> {
        let endpoint = self
            .endpoint
            .get_or_try_init(|| self.bind_endpoint())
            .await?;
        let connecting = endpoint.connect(server, APP_SERVER_PROTOCOL_NAME);
        let Ok(connected) = timeout(PEER_CONNECT_LIMIT, connecting).await
        else {
            return Err(NodeError::ServerUnreachable(
                LATE_CONNECTION.to_owned(),
            ));
        };
        connected.map_err(|problem| {
            NodeError::ServerUnreachable(problem.to_string())
        })
    }

    pub async fn close(&self) {
        if let Some(endpoint) = self.endpoint.get() {
            endpoint.close().await;
        }
    }

    async fn bind_endpoint(&self) -> Result<ServiceEndpoint, NodeError> {
        let secret_key = generate_peer_secret()?;
        let configuration = PeerConfiguration {
            secret_key: *secret_key,
            relay: self.relay.clone(),
        };
        let endpoint =
            ServiceEndpoint::bind(configuration, Vec::new()).await?;
        Ok(endpoint)
    }
}

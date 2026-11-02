use std::net::SocketAddr;

use iroh::endpoint::presets;
use iroh::{Endpoint, SecretKey};

use crate::peer_address::{
    PeerAddress, add_same_machine_addresses, build_endpoint_address,
    describe_endpoint_address,
};
use crate::peer_configuration::{PeerConfiguration, RelayChoice};
use crate::peer_connection::PeerConnection;
use crate::peer_error::PeerError;

pub const APP_SERVER_PROTOCOL_NAME: &[u8] =
    b"agents-orchestration/app-server/1";

#[derive(Debug)]
pub struct ServiceEndpoint {
    endpoint: Endpoint,
}

impl ServiceEndpoint {
    pub async fn bind(
        configuration: PeerConfiguration,
        accepted_protocols: Vec<Vec<u8>>,
    ) -> Result<Self, PeerError> {
        let relay_mode = configuration.relay.to_relay_mode()?;
        let secret_key = SecretKey::from_bytes(&configuration.secret_key);
        let builder = match configuration.relay {
            RelayChoice::Disabled => Endpoint::builder(presets::Minimal),
            RelayChoice::Default | RelayChoice::Custom(_) => {
                Endpoint::builder(presets::N0)
            }
        };
        let endpoint = builder
            .secret_key(secret_key)
            .alpns(accepted_protocols)
            .relay_mode(relay_mode)
            .bind()
            .await?;
        Ok(Self { endpoint })
    }

    #[must_use]
    pub fn peer_address(&self) -> PeerAddress {
        let bound_address = describe_endpoint_address(&self.endpoint.addr());
        add_same_machine_addresses(bound_address)
    }

    pub fn bound_ipv4_port(&self) -> Result<u16, PeerError> {
        let bound_sockets = self.endpoint.bound_sockets();
        let ipv4_socket = bound_sockets
            .iter()
            .find(|socket| socket.is_ipv4())
            .ok_or(PeerError::NoIpv4Socket)?;
        Ok(SocketAddr::port(ipv4_socket))
    }

    pub async fn connect(
        &self,
        peer_address: &PeerAddress,
        protocol_name: &[u8],
    ) -> Result<PeerConnection, PeerError> {
        let endpoint_address = build_endpoint_address(peer_address)?;
        let connection = self
            .endpoint
            .connect(endpoint_address, protocol_name)
            .await?;
        Ok(PeerConnection::new(connection))
    }

    pub async fn accept(&self) -> Result<PeerConnection, PeerError> {
        let incoming = self
            .endpoint
            .accept()
            .await
            .ok_or(PeerError::EndpointClosed)?;
        let connection = incoming.await?;
        Ok(PeerConnection::new(connection))
    }

    pub async fn close(&self) {
        self.endpoint.close().await;
    }
}

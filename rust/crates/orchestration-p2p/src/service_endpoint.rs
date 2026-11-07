use std::net::{Ipv4Addr, SocketAddr, SocketAddrV4};

use iroh::endpoint::{Builder, presets};
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
        let builder = prepare_builder(&configuration, accepted_protocols)?;
        let endpoint = builder.bind().await?;
        Ok(Self { endpoint })
    }

    pub async fn bind_preferring_ipv4_port(
        configuration: PeerConfiguration,
        accepted_protocols: Vec<Vec<u8>>,
        preferred_port: u16,
    ) -> Result<Self, PeerError> {
        let preferred_socket =
            SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, preferred_port);
        let builder =
            prepare_builder(&configuration, accepted_protocols.clone())?;
        let builder_on_preferred_port = builder.bind_addr(preferred_socket)?;
        if let Ok(endpoint) = builder_on_preferred_port.bind().await {
            return Ok(Self { endpoint });
        }
        Self::bind(configuration, accepted_protocols).await
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

fn prepare_builder(
    configuration: &PeerConfiguration,
    accepted_protocols: Vec<Vec<u8>>,
) -> Result<Builder, PeerError> {
    let relay_mode = configuration.relay.to_relay_mode()?;
    let secret_key = SecretKey::from_bytes(&configuration.secret_key);
    let builder = match configuration.relay {
        RelayChoice::Disabled => Endpoint::builder(presets::Minimal),
        RelayChoice::Default | RelayChoice::Custom(_) => {
            Endpoint::builder(presets::N0)
        }
    };
    Ok(builder
        .secret_key(secret_key)
        .alpns(accepted_protocols)
        .relay_mode(relay_mode))
}

use iroh::endpoint::presets;
use iroh::{Endpoint, SecretKey};

use crate::peer_address::{
    PeerAddress, build_endpoint_address, describe_endpoint_address,
};
use crate::peer_configuration::PeerConfiguration;
use crate::peer_error::PeerError;
use crate::peer_link::PeerLink;
use crate::record_board::RecordBoard;

pub const APPLICATION_PROTOCOL_NAME: &[u8] =
    b"agents-orchestration/peer-link/1";

#[derive(Debug)]
pub struct PeerEndpoint {
    endpoint: Endpoint,
}

impl PeerEndpoint {
    pub async fn bind(
        configuration: PeerConfiguration,
    ) -> Result<Self, PeerError> {
        let relay_mode = configuration.relay.to_relay_mode()?;
        let secret_key = SecretKey::from_bytes(&configuration.secret_key);
        let endpoint = Endpoint::builder(presets::Minimal)
            .secret_key(secret_key)
            .alpns(vec![APPLICATION_PROTOCOL_NAME.to_vec()])
            .relay_mode(relay_mode)
            .bind()
            .await?;
        Ok(Self { endpoint })
    }

    #[must_use]
    pub fn peer_address(&self) -> PeerAddress {
        describe_endpoint_address(&self.endpoint.addr())
    }

    pub async fn connect(
        &self,
        peer_address: &PeerAddress,
    ) -> Result<PeerLink, PeerError> {
        let endpoint_address = build_endpoint_address(peer_address)?;
        let connection = self
            .endpoint
            .connect(endpoint_address, APPLICATION_PROTOCOL_NAME)
            .await?;
        PeerLink::open(connection).await
    }

    pub async fn accept(&self) -> Result<PeerLink, PeerError> {
        let incoming = self
            .endpoint
            .accept()
            .await
            .ok_or(PeerError::EndpointClosed)?;
        let connection = incoming.await?;
        PeerLink::answer(connection).await
    }

    pub fn open_record_board(&self) -> Result<RecordBoard, PeerError> {
        let tls_configuration = self.endpoint.tls_config().clone();
        RecordBoard::open(tls_configuration)
    }

    pub async fn close(&self) {
        self.endpoint.close().await;
    }
}

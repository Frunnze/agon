use std::time::Duration;

use rustls::crypto::CryptoProvider;

use super::ServerAnswer;
use super::outgoing_request::OutgoingRequest;
use crate::node_error::NodeError;

const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Clone, Debug)]
pub(super) struct WebRoute {
    http_client: reqwest::Client,
    base_address: String,
}

impl WebRoute {
    pub(super) fn open(base_address: &str) -> Result<Self, NodeError> {
        install_crypto_provider()?;
        let http_client = reqwest::Client::builder()
            .connect_timeout(CONNECT_TIMEOUT)
            .build()
            .map_err(|error| NodeError::Startup(error.to_string()))?;
        Ok(Self {
            http_client,
            base_address: base_address.to_owned(),
        })
    }

    pub(super) async fn deliver(
        &self,
        request: OutgoingRequest,
    ) -> Result<ServerAnswer, NodeError> {
        let address = format!("{}{}", self.base_address, request.path);
        let mut builder = self
            .http_client
            .request(request.method, address)
            .timeout(request.timeout)
            .body(request.body);
        for (name, value) in request.headers {
            builder = builder.header(name, value);
        }

        let response = builder
            .send()
            .await
            .map_err(|error| describe_unreachable(&error))?;
        let status = response.status().as_u16();
        let body = response
            .bytes()
            .await
            .map_err(|error| describe_unreachable(&error))?;
        Ok(ServerAnswer {
            status,
            body: body.to_vec(),
        })
    }
}

fn describe_unreachable(error: &reqwest::Error) -> NodeError {
    NodeError::ServerUnreachable(error.to_string())
}

fn install_crypto_provider() -> Result<(), NodeError> {
    if CryptoProvider::get_default().is_some() {
        return Ok(());
    }
    let installation =
        rustls::crypto::ring::default_provider().install_default();
    let is_installed = CryptoProvider::get_default().is_some();
    if installation.is_err() && !is_installed {
        return Err(NodeError::Startup(
            "no TLS crypto provider could be installed".to_owned(),
        ));
    }
    Ok(())
}

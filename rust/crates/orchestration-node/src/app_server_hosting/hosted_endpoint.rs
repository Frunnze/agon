use std::fs;
use std::path::Path;

use orchestration_p2p::peer_configuration::PeerConfiguration;
use orchestration_p2p::service_endpoint::{
    APP_SERVER_PROTOCOL_NAME, ServiceEndpoint,
};
use orchestration_security::peer_addresses::{
    PeerSecret, generate_peer_secret,
};

use crate::identity_store::{FileIdentityStore, IdentityStore};
use crate::node_configuration::PeerRelayChoice;
use crate::node_error::NodeError;

const SERVER_IDENTITY_FILE_NAME: &str = "server-identity.key";

pub(super) async fn bind_hosted_endpoint(
    server_directory: &Path,
    relay: &PeerRelayChoice,
) -> Result<ServiceEndpoint, NodeError> {
    let peer_secret = find_or_create_server_secret(server_directory)?;
    let configuration = PeerConfiguration {
        secret_key: *peer_secret,
        relay: relay.to_relay_choice(),
    };
    let accepted_protocols = vec![APP_SERVER_PROTOCOL_NAME.to_vec()];
    let endpoint =
        ServiceEndpoint::bind(configuration, accepted_protocols).await?;
    Ok(endpoint)
}

fn find_or_create_server_secret(
    server_directory: &Path,
) -> Result<PeerSecret, NodeError> {
    fs::create_dir_all(server_directory)?;
    let identity_path = server_directory.join(SERVER_IDENTITY_FILE_NAME);
    let secret_store = FileIdentityStore::new(identity_path);
    if let Some(peer_secret) = secret_store.load_peer_secret()? {
        return Ok(peer_secret);
    }
    let peer_secret = generate_peer_secret()?;
    secret_store.save_peer_secret(&peer_secret)?;
    Ok(peer_secret)
}

use std::fs;
use std::path::Path;

use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::service_endpoint::{
    APP_SERVER_PROTOCOL_NAME, ServiceEndpoint,
};
use orchestration_security::peer_addresses::{
    PeerSecret, generate_peer_secret,
};
use serde::{Deserialize, Serialize};

use crate::device_files::{read_json_file, write_json_file};
use crate::identity_store::{FileIdentityStore, IdentityStore};
use crate::node_configuration::PeerRelayChoice;
use crate::node_error::NodeError;

const SERVER_IDENTITY_FILE_NAME: &str = "server-identity.key";
const PEER_PORT_FILE_NAME: &str = "peer-port.json";
const ANY_FREE_PORT: u16 = 0;

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct RememberedPeerPort {
    port: u16,
}

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
    if configuration.relay == RelayChoice::Disabled {
        return bind_on_remembered_port(
            server_directory,
            configuration,
            accepted_protocols,
        )
        .await;
    }
    let endpoint =
        ServiceEndpoint::bind(configuration, accepted_protocols).await?;
    Ok(endpoint)
}

async fn bind_on_remembered_port(
    server_directory: &Path,
    configuration: PeerConfiguration,
    accepted_protocols: Vec<Vec<u8>>,
) -> Result<ServiceEndpoint, NodeError> {
    let port_path = server_directory.join(PEER_PORT_FILE_NAME);
    let remembered: Option<RememberedPeerPort> = read_json_file(&port_path)?;
    let preferred_port =
        remembered.map_or(ANY_FREE_PORT, |remembered| remembered.port);
    let endpoint = ServiceEndpoint::bind_preferring_ipv4_port(
        configuration,
        accepted_protocols,
        preferred_port,
    )
    .await?;
    let bound = RememberedPeerPort {
        port: endpoint.bound_ipv4_port()?,
    };
    write_json_file(&port_path, &bound)?;
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

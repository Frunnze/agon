use std::sync::Arc;

use orchestration_node::node_error::NodeError;
use orchestration_node::server_address::ServerAddress;
use orchestration_node::server_client::{PeerDialer, ServerClient};
use orchestration_p2p::peer_configuration::RelayChoice;

use super::runner_access::test_runtime;
use super::test_device::describe;

pub fn use_server_at<Found>(
    address_text: &str,
    use_server: impl AsyncFnOnce(&ServerClient) -> Result<Found, NodeError>,
) -> Result<Found, String> {
    use_server_with_relay(address_text, RelayChoice::Disabled, use_server)
}

pub fn use_server_with_relay<Found>(
    address_text: &str,
    relay: RelayChoice,
    use_server: impl AsyncFnOnce(&ServerClient) -> Result<Found, NodeError>,
) -> Result<Found, String> {
    let address = ServerAddress::parse(address_text).map_err(describe)?;
    let runtime = test_runtime()?;
    let dialer = Arc::new(PeerDialer::new(relay));
    let server = ServerClient::connect(&address, &dialer).map_err(describe)?;
    runtime.block_on(async {
        let outcome = use_server(&server).await;
        dialer.close().await;
        outcome.map_err(describe)
    })
}

pub fn check_health_at(address_text: &str) -> Result<(), String> {
    use_server_at(address_text, async |server| server.check_health().await)
}

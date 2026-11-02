use std::sync::Arc;
use std::time::Duration;

use chrono::Utc;
use orchestration_api::accounts::PublishPeerAddressRequest;
use orchestration_security::peer_addresses::sign_peer_address;
use tokio::runtime::Runtime;
use tokio::task::JoinHandle;

use super::PeerSide;
use crate::node::Node;
use crate::node_error::NodeError;

const ANNOUNCE_CHECK_INTERVAL: Duration = Duration::from_secs(1);

pub(crate) fn start_announcer(
    runtime: &Runtime,
    node: Arc<Node>,
    peer_side: Arc<PeerSide>,
) -> JoinHandle<()> {
    runtime.spawn(async move {
        let mut timer = tokio::time::interval(ANNOUNCE_CHECK_INTERVAL);
        loop {
            timer.tick().await;
            announce_when_changed(&node, &peer_side).await;
        }
    })
}

async fn announce_when_changed(node: &Node, peer_side: &PeerSide) {
    let address = peer_side.current_address();
    if peer_side.is_published(&address) {
        return;
    }
    let session = match node.open_session() {
        Ok(session) => session,
        Err(NodeError::NoAccount | NodeError::NoAppServer) => return,
        Err(problem) => {
            peer_side.record_problem(&problem);
            return;
        }
    };

    let signed_address =
        sign_peer_address(&session.identity, &address, Utc::now());
    let request = PublishPeerAddressRequest {
        address: signed_address,
    };
    match session.client().publish_peer_address(&request).await {
        Ok(()) => peer_side.record_published(address),
        Err(problem) => peer_side.record_problem(&problem),
    }
}

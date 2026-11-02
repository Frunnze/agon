mod address_trust;
mod announcer;
mod file_connect;
mod live_connect;
mod live_watches;

use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use orchestration_core::peer_address::PeerAddress;
use orchestration_p2p::peer_address::add_same_machine_addresses;
use orchestration_p2p::peer_configuration::PeerConfiguration;
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_p2p::record_board::RecordBoard;
use serde::Serialize;
use tokio::runtime::Runtime;

pub(crate) use address_trust::trusted_peer_address;
pub(crate) use announcer::start_announcer;
pub(crate) use file_connect::ask_runner_for_files;
pub(crate) use live_connect::connect_to_runner;
pub(crate) use live_watches::LiveWatches;

use crate::node::Node;
use crate::node_configuration::PeerRelayChoice;
use crate::node_error::NodeError;

#[derive(Clone, Debug, Default, Serialize)]
pub(crate) struct AnnouncementState {
    pub(crate) published_address: Option<PeerAddress>,
    pub(crate) problem: Option<String>,
}

#[derive(Debug)]
pub(crate) struct PeerSide {
    pub(crate) endpoint: Arc<PeerEndpoint>,
    pub(crate) record_board: RecordBoard,
    pub(crate) watches: LiveWatches,
    announcement: Mutex<AnnouncementState>,
}

impl PeerSide {
    pub(crate) fn bind(
        runtime: &Runtime,
        node: &Node,
        relay: &PeerRelayChoice,
    ) -> Result<Self, NodeError> {
        let peer_secret = node.find_or_create_peer_secret()?;
        let configuration = PeerConfiguration {
            secret_key: *peer_secret,
            relay: relay.to_relay_choice(),
        };
        let endpoint = runtime.block_on(PeerEndpoint::bind(configuration))?;
        let record_board = endpoint.open_record_board()?;
        Ok(Self {
            endpoint: Arc::new(endpoint),
            record_board,
            watches: LiveWatches::default(),
            announcement: Mutex::new(AnnouncementState::default()),
        })
    }

    pub(crate) fn current_address(&self) -> PeerAddress {
        add_same_machine_addresses(self.endpoint.peer_address())
    }

    pub(crate) fn announcement(&self) -> AnnouncementState {
        self.lock_announcement().clone()
    }

    fn is_published(&self, address: &PeerAddress) -> bool {
        let announcement = self.lock_announcement();
        announcement.published_address.as_ref() == Some(address)
    }

    fn record_published(&self, address: PeerAddress) {
        let mut announcement = self.lock_announcement();
        announcement.published_address = Some(address);
        announcement.problem = None;
    }

    fn record_problem(&self, problem: &NodeError) {
        self.lock_announcement().problem = Some(problem.to_string());
    }

    fn lock_announcement(&self) -> MutexGuard<'_, AnnouncementState> {
        self.announcement
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }
}

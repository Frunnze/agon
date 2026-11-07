use std::collections::BTreeSet;
use std::net::SocketAddr;

use mdns_sd::{Receiver, ResolvedService, ServiceDaemon, ServiceEvent};
use orchestration_core::peer_address::{
    ENDPOINT_PUBLIC_KEY_LENGTH, PeerAddress,
};

use super::{
    APP_SERVER_SERVICE_TYPE, SERVER_ADDRESS_PROPERTY,
    describe_local_network_problem,
};
use crate::node_error::NodeError;
use crate::server_address::ServerAddress;

pub(crate) struct LocalNetworkSearch {
    daemon: ServiceDaemon,
    events: Receiver<ServiceEvent>,
    offered_addresses: BTreeSet<String>,
}

impl LocalNetworkSearch {
    pub(crate) fn start() -> Result<Self, NodeError> {
        let daemon = ServiceDaemon::new()
            .map_err(|problem| describe_local_network_problem(&problem))?;
        let events = daemon
            .browse(APP_SERVER_SERVICE_TYPE)
            .map_err(|problem| describe_local_network_problem(&problem))?;
        Ok(Self {
            daemon,
            events,
            offered_addresses: BTreeSet::new(),
        })
    }

    pub(crate) async fn next_server_address(
        &mut self,
    ) -> Option<ServerAddress> {
        while let Ok(event) = self.events.recv_async().await {
            let ServiceEvent::ServiceResolved(service) = event else {
                continue;
            };
            let Some(server_address) = read_announced_address(&service) else {
                continue;
            };
            if self.offered_addresses.insert(server_address.to_string()) {
                return Some(server_address);
            }
        }
        None
    }

    pub(crate) async fn find_peer_address(
        &mut self,
        endpoint_public_key: &[u8; ENDPOINT_PUBLIC_KEY_LENGTH],
    ) -> Option<PeerAddress> {
        while let Some(server_address) = self.next_server_address().await {
            let ServerAddress::Peer(peer_address) = server_address else {
                continue;
            };
            if peer_address.endpoint_public_key == *endpoint_public_key {
                return Some(peer_address);
            }
        }
        None
    }
}

impl Drop for LocalNetworkSearch {
    fn drop(&mut self) {
        let _stopping = self.daemon.shutdown();
    }
}

fn read_announced_address(service: &ResolvedService) -> Option<ServerAddress> {
    let announced_text =
        service.get_property_val_str(SERVER_ADDRESS_PROPERTY)?;
    let announced_address = ServerAddress::parse(announced_text).ok()?;
    let mut direct_addresses = Vec::new();
    for local_address in service.get_addresses_v4() {
        let port = service.get_port();
        direct_addresses.push(SocketAddr::from((local_address, port)));
    }
    Some(announced_address.with_direct_addresses(&direct_addresses))
}

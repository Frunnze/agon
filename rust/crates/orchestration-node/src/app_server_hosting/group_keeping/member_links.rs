use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::Duration;

use orchestration_api::server_group::{
    JoinServerGroupRequest, ServerGroupView,
};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::peer_address::PeerAddress;
use orchestration_core::server_group::{ServerGroup, ServerMember};
use orchestration_core::server_keeping::ProbeAnswer;
use orchestration_security::identity::DeviceIdentity;
use orchestration_server::REPLICA_WAIT;
use tokio::time::timeout;

use crate::node_error::NodeError;
use crate::server_address::ServerAddress;
use crate::server_client::{PeerDialer, ServerClient};

const PROBE_LIMIT: Duration = Duration::from_secs(3);
const REPLICA_ANSWER_MARGIN: Duration = Duration::from_secs(5);
const LATE_PROBE: &str = "the app server did not answer the probe in time";
const UNKNOWN_SERVER_KIND: &str = "app server";

type CachedClient = (PeerAddress, ServerClient);

#[derive(Debug)]
pub(super) struct MemberLinks {
    identity: Arc<DeviceIdentity>,
    dialer: Arc<PeerDialer>,
    addresses: BTreeMap<DeviceId, PeerAddress>,
    clients: BTreeMap<DeviceId, CachedClient>,
}

impl MemberLinks {
    pub(super) fn new(
        identity: Arc<DeviceIdentity>,
        dialer: Arc<PeerDialer>,
    ) -> Self {
        Self {
            identity,
            dialer,
            addresses: BTreeMap::new(),
            clients: BTreeMap::new(),
        }
    }

    pub(super) fn remember_addresses(&mut self, group: &ServerGroup) {
        for member in &group.members {
            let server_id = member.membership.server_id.clone();
            self.addresses.insert(server_id, member.address.clone());
        }
    }

    pub(super) async fn probe_members(
        &mut self,
        group: &ServerGroup,
        own_server_id: &DeviceId,
    ) -> Vec<ProbeAnswer> {
        let mut answers = Vec::new();
        for member in &group.members {
            let server_id = &member.membership.server_id;
            if server_id == own_server_id {
                continue;
            }
            if let Ok(view) = self.probe(server_id).await {
                self.remember_addresses(&view.group);
                answers.push(ProbeAnswer {
                    server_id: server_id.clone(),
                    term: view.group.term,
                    standing: view.standing,
                });
            }
        }
        answers
    }

    pub(super) async fn fetch_replica(
        &mut self,
        server_id: &DeviceId,
        after_revision: u64,
    ) -> Result<Option<Vec<u8>>, NodeError> {
        let client = self.client_for(server_id)?;
        let longest_wait = REPLICA_WAIT + REPLICA_ANSWER_MARGIN;
        client
            .signed(&self.identity)
            .fetch_replica(after_revision, longest_wait)
            .await
    }

    pub(super) async fn send_own_member(
        &mut self,
        server_id: &DeviceId,
        member: ServerMember,
    ) -> Result<(), NodeError> {
        let client = self.client_for(server_id)?;
        let request = JoinServerGroupRequest { member };
        client
            .signed(&self.identity)
            .join_server_group(&request)
            .await?;
        Ok(())
    }

    async fn probe(
        &mut self,
        server_id: &DeviceId,
    ) -> Result<ServerGroupView, NodeError> {
        let client = self.client_for(server_id)?;
        let signed = client.signed(&self.identity);
        timeout(PROBE_LIMIT, signed.read_server_group())
            .await
            .unwrap_or_else(|_| {
                Err(NodeError::ServerUnreachable(LATE_PROBE.to_owned()))
            })
    }

    fn client_for(
        &mut self,
        server_id: &DeviceId,
    ) -> Result<ServerClient, NodeError> {
        let address =
            self.addresses.get(server_id).cloned().ok_or_else(|| {
                NodeError::NotFound {
                    kind: UNKNOWN_SERVER_KIND,
                    identifier: server_id.0.clone(),
                }
            })?;
        if let Some((known_address, client)) = self.clients.get(server_id)
            && *known_address == address
        {
            return Ok(client.clone());
        }
        let server_address = ServerAddress::Peer(address.clone());
        let client = ServerClient::connect(&server_address, &self.dialer)?;
        self.clients
            .insert(server_id.clone(), (address, client.clone()));
        Ok(client)
    }
}

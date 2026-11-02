use chrono::{DateTime, TimeDelta, Utc};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::peer_address::PeerAddress;
use orchestration_core::server_group::{
    AuditSigners, ServerGroup, ServerMember, ServerMembership, ServerTerm,
};
use proptest::collection::vec;
use proptest::prelude::*;

use super::address_strategies::peer_address_strategy;

const MOST_MEMBERS: usize = 4;

pub fn hex_key(address: &PeerAddress) -> String {
    hex::encode(address.endpoint_public_key)
}

fn member_at(address: PeerAddress, position: i64) -> ServerMember {
    let server_id = DeviceId(hex_key(&address));
    ServerMember {
        membership: ServerMembership {
            device_id: server_id.clone(),
            server_id,
            server_signing_public_key: Vec::new(),
            endpoint_public_key: address.endpoint_public_key,
            joined_at: DateTime::<Utc>::UNIX_EPOCH
                + TimeDelta::seconds(position),
            signature: Vec::new(),
        },
        address,
    }
}

pub fn group_strategy() -> impl Strategy<Value = ServerGroup> {
    (
        vec(peer_address_strategy(), 1..MOST_MEMBERS),
        any::<prop::sample::Index>(),
    )
        .prop_map(|(addresses, active_index)| {
            let members: Vec<ServerMember> = (0_i64..)
                .zip(addresses)
                .map(|(position, address)| member_at(address, position))
                .collect();
            let active = active_index.get(&members).membership.clone();
            ServerGroup {
                term: Some(ServerTerm {
                    number: 1,
                    server_id: active.server_id,
                    claimed_by: active.device_id,
                    signature: Vec::new(),
                }),
                members,
                audit_signers: AuditSigners::new(),
            }
        })
}

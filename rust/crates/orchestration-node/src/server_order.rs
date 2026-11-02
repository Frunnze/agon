use orchestration_core::peer_address::ENDPOINT_PUBLIC_KEY_LENGTH;
use orchestration_core::server_group::{ServerGroup, ServerMember};

use crate::server_address::ServerAddress;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OwnServerRoute {
    pub endpoint_public_key: [u8; ENDPOINT_PUBLIC_KEY_LENGTH],
    pub local_address: ServerAddress,
}

#[must_use]
pub fn order_server_addresses(
    primary: &ServerAddress,
    group: Option<&ServerGroup>,
    own_server: Option<&OwnServerRoute>,
) -> Vec<ServerAddress> {
    let mut ordered = Vec::new();
    if let Some(group) = group {
        for member in group.members_active_first() {
            let address = choose_member_address(member, own_server);
            push_new_server(&mut ordered, address);
        }
    }
    push_new_server(&mut ordered, primary.clone());
    ordered
}

fn choose_member_address(
    member: &ServerMember,
    own_server: Option<&OwnServerRoute>,
) -> ServerAddress {
    let member_key = member.address.endpoint_public_key;
    match own_server {
        Some(own) if own.endpoint_public_key == member_key => {
            own.local_address.clone()
        }
        _ => ServerAddress::Peer(member.address.clone()),
    }
}

fn push_new_server(ordered: &mut Vec<ServerAddress>, address: ServerAddress) {
    let is_known = ordered.iter().any(|known| is_same_server(known, &address));
    if !is_known {
        ordered.push(address);
    }
}

fn is_same_server(first: &ServerAddress, second: &ServerAddress) -> bool {
    match (first, second) {
        (ServerAddress::Peer(first), ServerAddress::Peer(second)) => {
            first.endpoint_public_key == second.endpoint_public_key
        }
        (ServerAddress::Web(first), ServerAddress::Web(second)) => {
            first == second
        }
        _ => false,
    }
}

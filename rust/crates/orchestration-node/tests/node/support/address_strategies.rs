use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};

use orchestration_core::peer_address::PeerAddress;
use orchestration_node::server_address::ServerAddress;
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH,
};
use proptest::prelude::*;

const DIRECT_ADDRESS_LIMIT: usize = 5;
const RELAY_PATTERN: &str = "https://[a-z]{1,12}\\.example\\.org/";
const WEB_PATTERN: &str =
    "https?://[a-z]{1,12}(\\.[a-z]{2,6})?(:[1-9][0-9]{1,3})?";

fn endpoint_key_strategy() -> impl Strategy<Value = [u8; 32]> {
    any::<[u8; IDENTITY_SECRET_LENGTH]>().prop_filter_map(
        "the secret makes a device key",
        |secret| {
            let identity = DeviceIdentity::from_secret_bytes(&secret).ok()?;
            let public_key = identity.public_identity().signing_public_key;
            public_key.try_into().ok()
        },
    )
}

pub fn direct_address_strategy() -> impl Strategy<Value = SocketAddr> {
    prop_oneof![
        (any::<[u8; 4]>(), 1..u16::MAX).prop_map(|(octets, port)| {
            SocketAddr::new(IpAddr::V4(Ipv4Addr::from(octets)), port)
        }),
        (any::<[u8; 16]>(), 1..u16::MAX).prop_map(|(octets, port)| {
            SocketAddr::new(IpAddr::V6(Ipv6Addr::from(octets)), port)
        }),
    ]
}

pub fn direct_addresses_strategy() -> impl Strategy<Value = Vec<SocketAddr>> {
    prop::collection::vec(direct_address_strategy(), 0..DIRECT_ADDRESS_LIMIT)
}

pub fn peer_address_strategy() -> impl Strategy<Value = PeerAddress> {
    (
        endpoint_key_strategy(),
        direct_addresses_strategy(),
        prop::option::of(RELAY_PATTERN),
    )
        .prop_map(|(endpoint_public_key, direct_addresses, relay_url)| {
            PeerAddress {
                endpoint_public_key,
                direct_addresses,
                relay_url,
            }
        })
}

pub fn server_address_strategy() -> impl Strategy<Value = ServerAddress> {
    prop_oneof![
        WEB_PATTERN.prop_map(ServerAddress::Web),
        peer_address_strategy().prop_map(ServerAddress::Peer),
    ]
}

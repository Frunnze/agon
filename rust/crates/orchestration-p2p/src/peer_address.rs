use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};

use iroh::{EndpointAddr, PublicKey, TransportAddr};
pub use orchestration_core::peer_address::{
    ENDPOINT_PUBLIC_KEY_LENGTH, PeerAddress,
};

use crate::peer_configuration::parse_relay_url;
use crate::peer_error::PeerError;

#[must_use]
pub fn add_same_machine_addresses(peer_address: PeerAddress) -> PeerAddress {
    let mut direct_addresses = peer_address.direct_addresses.clone();
    for bound in &peer_address.direct_addresses {
        let loopback = if bound.is_ipv4() {
            IpAddr::V4(Ipv4Addr::LOCALHOST)
        } else {
            IpAddr::V6(Ipv6Addr::LOCALHOST)
        };
        let same_machine = SocketAddr::new(loopback, bound.port());
        if !direct_addresses.contains(&same_machine) {
            direct_addresses.push(same_machine);
        }
    }
    PeerAddress {
        direct_addresses,
        ..peer_address
    }
}

pub fn check_peer_address(
    peer_address: &PeerAddress,
) -> Result<(), PeerError> {
    build_endpoint_address(peer_address)?;
    Ok(())
}

pub(crate) fn describe_endpoint_address(
    endpoint_address: &EndpointAddr,
) -> PeerAddress {
    let direct_addresses = endpoint_address.ip_addrs().copied().collect();
    let relay_url = endpoint_address
        .relay_urls()
        .next()
        .map(ToString::to_string);
    PeerAddress {
        endpoint_public_key: *endpoint_address.id.as_bytes(),
        direct_addresses,
        relay_url,
    }
}

pub(crate) fn build_endpoint_address(
    peer_address: &PeerAddress,
) -> Result<EndpointAddr, PeerError> {
    let endpoint_public_key =
        PublicKey::from_bytes(&peer_address.endpoint_public_key)
            .map_err(PeerError::InvalidPublicKey)?;
    let mut transport_addresses = Vec::new();
    for direct_address in &peer_address.direct_addresses {
        transport_addresses.push(TransportAddr::Ip(*direct_address));
    }
    if let Some(relay_url) = &peer_address.relay_url {
        let parsed_relay_url = parse_relay_url(relay_url)?;
        transport_addresses.push(TransportAddr::Relay(parsed_relay_url));
    }
    Ok(EndpointAddr::from_parts(
        endpoint_public_key,
        transport_addresses,
    ))
}

use std::net::{Ipv4Addr, SocketAddr};

use orchestration_p2p::peer_address::PeerAddress;
use orchestration_p2p::peer_configuration::{
    PeerConfiguration, RelayChoice, SECRET_KEY_LENGTH,
};
use proptest::prelude::*;
use tokio::runtime::{Builder, Runtime};

const PAYLOAD_SIZE_LIMIT: usize = 4096;
const FRAME_COUNT_LIMIT: usize = 24;

pub type FrameSequence = Vec<Vec<u8>>;
pub type SecretKeyBytes = [u8; SECRET_KEY_LENGTH];

pub fn local_configuration(secret_key: SecretKeyBytes) -> PeerConfiguration {
    PeerConfiguration {
        secret_key,
        relay: RelayChoice::Disabled,
    }
}

pub fn build_runtime() -> Result<Runtime, std::io::Error> {
    Builder::new_multi_thread().enable_all().build()
}

pub fn arbitrary_frame_sequence() -> impl Strategy<Value = FrameSequence> {
    let payload = prop::collection::vec(any::<u8>(), 0..PAYLOAD_SIZE_LIMIT);
    prop::collection::vec(payload, 0..FRAME_COUNT_LIMIT)
}

pub fn localhost_address_of(peer_address: PeerAddress) -> PeerAddress {
    let mut localhost_addresses = Vec::new();
    for direct_address in &peer_address.direct_addresses {
        if direct_address.is_ipv4() {
            let localhost_port = direct_address.port();
            let localhost_address =
                SocketAddr::from((Ipv4Addr::LOCALHOST, localhost_port));
            localhost_addresses.push(localhost_address);
        }
    }
    PeerAddress {
        direct_addresses: localhost_addresses,
        ..peer_address
    }
}

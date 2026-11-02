use std::net::SocketAddr;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::identifiers::DeviceId;

pub const ENDPOINT_PUBLIC_KEY_LENGTH: usize = 32;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PeerAddress {
    pub endpoint_public_key: [u8; ENDPOINT_PUBLIC_KEY_LENGTH],
    pub direct_addresses: Vec<SocketAddr>,
    pub relay_url: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SignedPeerAddress {
    pub device_id: DeviceId,
    pub address: PeerAddress,
    pub published_at: DateTime<Utc>,
    pub signature: Vec<u8>,
}

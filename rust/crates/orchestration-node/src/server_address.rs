mod peer_text;

use std::fmt;
use std::net::SocketAddr;

use orchestration_core::peer_address::PeerAddress;
use reqwest::Url;

use crate::node_error::NodeError;
use peer_text::{parse_peer_address, render_peer_address};

pub const PEER_SCHEME_PREFIX: &str = "peer://";
const PEER_SCHEME: &str = "peer";
const WEB_SCHEMES: [&str; 2] = ["http", "https"];
const ADDRESS_SEPARATOR: char = '/';

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ServerAddress {
    Web(String),
    Peer(PeerAddress),
}

impl ServerAddress {
    pub fn parse(text: &str) -> Result<Self, NodeError> {
        let refuse = || NodeError::InvalidServerAddress(text.to_owned());
        let parsed = Url::parse(text).map_err(|_| refuse())?;
        if WEB_SCHEMES.contains(&parsed.scheme()) {
            let trimmed = parsed.as_str().trim_end_matches(ADDRESS_SEPARATOR);
            return Ok(Self::Web(trimmed.to_owned()));
        }
        if parsed.scheme() != PEER_SCHEME {
            return Err(refuse());
        }
        let peer_address = parse_peer_address(&parsed).ok_or_else(refuse)?;
        Ok(Self::Peer(peer_address))
    }

    #[must_use]
    pub fn direct_addresses(&self) -> &[SocketAddr] {
        match self {
            Self::Web(_) => &[],
            Self::Peer(peer_address) => &peer_address.direct_addresses,
        }
    }

    #[must_use]
    pub fn without_direct_addresses(&self) -> Self {
        match self {
            Self::Web(web_address) => Self::Web(web_address.clone()),
            Self::Peer(peer_address) => Self::Peer(PeerAddress {
                direct_addresses: Vec::new(),
                ..peer_address.clone()
            }),
        }
    }

    #[must_use]
    pub fn with_direct_addresses(self, extra: &[SocketAddr]) -> Self {
        match self {
            Self::Web(web_address) => Self::Web(web_address),
            Self::Peer(peer_address) => {
                let mut direct_addresses = peer_address.direct_addresses;
                direct_addresses.extend_from_slice(extra);
                Self::Peer(PeerAddress {
                    direct_addresses,
                    ..peer_address
                })
            }
        }
    }
}

impl fmt::Display for ServerAddress {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Web(web_address) => formatter.write_str(web_address),
            Self::Peer(peer_address) => {
                formatter.write_str(&render_peer_address(peer_address))
            }
        }
    }
}

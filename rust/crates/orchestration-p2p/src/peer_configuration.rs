use std::fmt;

use iroh::{RelayMode, RelayUrl};

use crate::peer_error::PeerError;

pub const SECRET_KEY_LENGTH: usize = 32;

pub struct PeerConfiguration {
    pub secret_key: [u8; SECRET_KEY_LENGTH],
    pub relay: RelayChoice,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RelayChoice {
    Disabled,
    Default,
    Custom(String),
}

impl fmt::Debug for PeerConfiguration {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("PeerConfiguration")
            .field("relay", &self.relay)
            .finish_non_exhaustive()
    }
}

impl RelayChoice {
    pub(crate) fn to_relay_mode(&self) -> Result<RelayMode, PeerError> {
        match self {
            Self::Disabled => Ok(RelayMode::Disabled),
            Self::Default => Ok(RelayMode::Default),
            Self::Custom(relay_url) => {
                let parsed_relay_url = parse_relay_url(relay_url)?;
                Ok(RelayMode::custom([parsed_relay_url]))
            }
        }
    }
}

pub(crate) fn parse_relay_url(relay_url: &str) -> Result<RelayUrl, PeerError> {
    relay_url
        .parse()
        .map_err(|source| PeerError::InvalidRelayUrl {
            relay_url: relay_url.to_owned(),
            source,
        })
}

use iroh::endpoint::{
    BindError, ClosedStream, ConnectError, ConnectingError, ConnectionError,
    InvalidSocketAddr, ReadExactError, StoppedError, WriteError,
};
use iroh::{KeyParsingError, RelayUrlParseError};
use thiserror::Error;

use crate::frame_codec::FrameError;

#[derive(Debug, Error)]
pub enum PeerError {
    #[error("relay url {relay_url:?} is not valid")]
    InvalidRelayUrl {
        relay_url: String,
        #[source]
        source: RelayUrlParseError,
    },
    #[error("endpoint public key is not a valid key")]
    InvalidPublicKey(#[source] KeyParsingError),
    #[error("endpoint could not bind: {0}")]
    Bind(#[from] BindError),
    #[error("endpoint bind address is not valid: {0}")]
    InvalidBindAddress(#[from] InvalidSocketAddr),
    #[error("could not connect to the peer: {0}")]
    Connect(#[from] ConnectError),
    #[error("incoming connection failed: {0}")]
    Incoming(#[from] ConnectingError),
    #[error("link stream could not be opened: {0}")]
    StreamOpening(#[from] ConnectionError),
    #[error("link greeting could not be sent: {0}")]
    GreetingNotSent(#[from] WriteError),
    #[error("link greeting could not be received: {0}")]
    GreetingNotReceived(#[from] ReadExactError),
    #[error("peer opened the link with an unexpected greeting")]
    UnexpectedGreeting,
    #[error("endpoint is closed")]
    EndpointClosed,
    #[error(transparent)]
    Frame(#[from] FrameError),
    #[error("link was already finished: {0}")]
    AlreadyFinished(#[from] ClosedStream),
    #[error("peer did not acknowledge the closing link: {0}")]
    CloseNotAcknowledged(#[from] StoppedError),
    #[error("the peer stream failed: {0}")]
    Stream(std::io::Error),
    #[error("the endpoint has no IPv4 socket")]
    NoIpv4Socket,
    #[error("the signed record could not be built: {0}")]
    RecordNotBuilt(String),
    #[error("the public record board could not be reached: {0}")]
    RecordBoardUnreachable(String),
    #[error("the public record board answered {0}")]
    RecordRefused(u16),
    #[error("the published record cannot be trusted: {0}")]
    UnreadableRecord(String),
}

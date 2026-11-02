use iroh::endpoint::{Connection, RecvStream, SendStream, VarInt};
use tokio::io::{Join, join};

use crate::peer_error::PeerError;

const CONNECTION_CLOSED_CODE: VarInt = VarInt::from_u32(0);
const CONNECTION_CLOSED_REASON: &[u8] = b"connection closed";

pub type PeerStream = Join<RecvStream, SendStream>;

#[derive(Clone, Debug)]
pub struct PeerConnection {
    connection: Connection,
}

impl PeerConnection {
    pub(crate) fn new(connection: Connection) -> Self {
        Self { connection }
    }

    pub async fn open_stream(&self) -> Result<PeerStream, PeerError> {
        let (send_stream, receive_stream) = self.connection.open_bi().await?;
        Ok(join(receive_stream, send_stream))
    }

    pub async fn accept_stream(&self) -> Result<PeerStream, PeerError> {
        let (send_stream, receive_stream) =
            self.connection.accept_bi().await?;
        Ok(join(receive_stream, send_stream))
    }

    #[must_use]
    pub fn is_closed(&self) -> bool {
        self.connection.close_reason().is_some()
    }

    pub async fn closed(&self) {
        self.connection.closed().await;
    }

    pub fn close(&self) {
        self.connection
            .close(CONNECTION_CLOSED_CODE, CONNECTION_CLOSED_REASON);
    }
}

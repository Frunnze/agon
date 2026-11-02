use iroh::endpoint::{
    Connection, ConnectionError, Path, RecvStream, SendStream, StoppedError,
    VarInt,
};
use orchestration_core::device::RunnerLink;

use crate::frame_codec::{read_frame, write_frame};
use crate::peer_address::ENDPOINT_PUBLIC_KEY_LENGTH;
use crate::peer_error::PeerError;

const LINK_GREETING: [u8; 4] = *b"link";
const LINK_CLOSED_CODE: VarInt = VarInt::from_u32(0);
const LINK_CLOSED_REASON: &[u8] = b"link closed";

#[derive(Debug)]
pub struct PeerLink {
    pub sender: PeerLinkSender,
    pub receiver: PeerLinkReceiver,
}

#[derive(Debug)]
pub struct PeerLinkSender {
    connection: Connection,
    send_stream: SendStream,
}

#[derive(Debug)]
pub struct PeerLinkReceiver {
    receive_stream: RecvStream,
}

impl PeerLink {
    pub(crate) async fn open(
        connection: Connection,
    ) -> Result<Self, PeerError> {
        let (mut send_stream, receive_stream) = connection.open_bi().await?;
        send_stream.write_all(&LINK_GREETING).await?;
        Ok(Self::from_parts(connection, send_stream, receive_stream))
    }

    pub(crate) async fn answer(
        connection: Connection,
    ) -> Result<Self, PeerError> {
        let (send_stream, mut receive_stream) = connection.accept_bi().await?;
        let mut received_greeting = [0; LINK_GREETING.len()];
        receive_stream.read_exact(&mut received_greeting).await?;
        if received_greeting != LINK_GREETING {
            return Err(PeerError::UnexpectedGreeting);
        }
        Ok(Self::from_parts(connection, send_stream, receive_stream))
    }

    fn from_parts(
        connection: Connection,
        send_stream: SendStream,
        receive_stream: RecvStream,
    ) -> Self {
        Self {
            sender: PeerLinkSender {
                connection,
                send_stream,
            },
            receiver: PeerLinkReceiver { receive_stream },
        }
    }
}

impl PeerLinkSender {
    pub async fn send_frame(
        &mut self,
        payload: &[u8],
    ) -> Result<(), PeerError> {
        write_frame(&mut self.send_stream, payload).await?;
        Ok(())
    }

    #[must_use]
    pub fn link_kind(&self) -> RunnerLink {
        let open_paths = self.connection.paths();
        let selected_path = open_paths.iter().find(Path::is_selected);
        match selected_path {
            Some(path) if path.is_ip() => RunnerLink::Direct,
            Some(path) if path.is_relay() => RunnerLink::Relay,
            _ if open_paths.iter().any(|path| path.is_ip()) => {
                RunnerLink::Direct
            }
            _ if open_paths.iter().any(|path| path.is_relay()) => {
                RunnerLink::Relay
            }
            _ => RunnerLink::Unreachable,
        }
    }

    #[must_use]
    pub fn remote_public_key(&self) -> [u8; ENDPOINT_PUBLIC_KEY_LENGTH] {
        let remote_endpoint_id = self.connection.remote_id();
        *remote_endpoint_id.as_bytes()
    }

    pub async fn close(mut self) -> Result<(), PeerError> {
        self.send_stream.finish()?;
        let acknowledgement = self.send_stream.stopped().await;
        self.connection.close(LINK_CLOSED_CODE, LINK_CLOSED_REASON);
        match acknowledgement {
            Ok(_)
            | Err(StoppedError::ConnectionLost(
                ConnectionError::ApplicationClosed(_),
            )) => Ok(()),
            Err(stopped_error) => Err(PeerError::from(stopped_error)),
        }
    }
}

impl PeerLinkReceiver {
    pub async fn receive_frame(
        &mut self,
    ) -> Result<Option<Vec<u8>>, PeerError> {
        let received_frame = read_frame(&mut self.receive_stream).await?;
        Ok(received_frame)
    }
}

use std::time::Duration;

use orchestration_core::device::Device;
use orchestration_core::peer_address::PeerAddress;
use tokio::time::timeout;

use super::PeerSide;
use super::address_trust::trusted_peer_address;
use crate::live_link_messages::{
    ClientMessage, FileAnswer, FileRequest, RunnerMessage,
    decode_link_message, encode_link_message,
};
use crate::node_error::NodeError;

const FILE_ANSWER_LIMIT: Duration = Duration::from_secs(30);
const CLOSED_BEFORE_ANSWER: &str = "the runner closed the link";
const ANSWER_WITHOUT_FILES: &str = "the runner answered without files";

pub(crate) async fn ask_runner_for_files(
    peer_side: &PeerSide,
    runner: &Device,
    request: FileRequest,
) -> Result<FileAnswer, NodeError> {
    let address = trusted_peer_address(runner)?;
    let asking = exchange_file_request(peer_side, address, request);
    timeout(FILE_ANSWER_LIMIT, asking)
        .await
        .map_err(|_| NodeError::LinkTimedOut)?
}

async fn exchange_file_request(
    peer_side: &PeerSide,
    address: &PeerAddress,
    request: FileRequest,
) -> Result<FileAnswer, NodeError> {
    let mut link = peer_side.endpoint.connect(address).await?;
    if link.sender.remote_public_key() != address.endpoint_public_key {
        return Err(NodeError::UntrustedPeer);
    }
    let frame = encode_link_message(&ClientMessage::Browse { request })?;
    link.sender.send_frame(&frame).await?;

    let answer = link.receiver.receive_frame().await?;
    let answer = answer
        .ok_or_else(|| NodeError::FilesRefused(CLOSED_BEFORE_ANSWER.into()))?;
    match decode_link_message::<RunnerMessage>(&answer)? {
        RunnerMessage::Answered { answer } => Ok(answer),
        RunnerMessage::Refused { reason } => {
            Err(NodeError::FilesRefused(reason))
        }
        RunnerMessage::Accepted | RunnerMessage::Events { .. } => Err(
            NodeError::MalformedLinkMessage(ANSWER_WITHOUT_FILES.to_owned()),
        ),
    }
}

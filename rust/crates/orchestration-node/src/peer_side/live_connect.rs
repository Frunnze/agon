use std::time::Duration;

use orchestration_core::device::Device;
use orchestration_core::identifiers::{DeviceId, RunId};
use orchestration_core::peer_address::PeerAddress;
use orchestration_core::run::{Run, StepStatus};
use orchestration_p2p::peer_link::PeerLink;
use tokio::time::timeout;

use super::PeerSide;
use super::address_trust::trusted_peer_address;
use crate::live_link_messages::{
    ClientMessage, RunnerMessage, decode_link_message, encode_link_message,
};
use crate::node_error::NodeError;

const LINK_ANSWER_LIMIT: Duration = Duration::from_secs(5);
const ACTIVE_STEP_STATUSES: [StepStatus; 2] =
    [StepStatus::Running, StepStatus::WaitingForApproval];
const CLOSED_BEFORE_ANSWER: &str = "the runner closed the link";
const EVENTS_BEFORE_ANSWER: &str = "the runner sent events before accepting";

pub(crate) async fn connect_to_runner(
    peer_side: &PeerSide,
    devices: &[Device],
    run: &Run,
) -> Result<PeerLink, NodeError> {
    let runner_id =
        find_active_runner(run).ok_or(NodeError::NoActiveRunner)?;
    let runner = devices
        .iter()
        .find(|device| &device.id == runner_id && !device.revoked)
        .ok_or(NodeError::NoActiveRunner)?;
    let address = trusted_peer_address(runner)?;
    let opening = open_watch(peer_side, address, run.id);
    timeout(LINK_ANSWER_LIMIT, opening)
        .await
        .map_err(|_| NodeError::LinkTimedOut)?
}

async fn open_watch(
    peer_side: &PeerSide,
    address: &PeerAddress,
    run_id: RunId,
) -> Result<PeerLink, NodeError> {
    let mut link = peer_side.endpoint.connect(address).await?;
    if link.sender.remote_public_key() != address.endpoint_public_key {
        return Err(NodeError::UntrustedPeer);
    }
    let request = encode_link_message(&ClientMessage::Watch { run_id })?;
    link.sender.send_frame(&request).await?;

    let answer = link.receiver.receive_frame().await?;
    let answer = answer
        .ok_or_else(|| NodeError::LinkRefused(CLOSED_BEFORE_ANSWER.into()))?;
    match decode_link_message::<RunnerMessage>(&answer)? {
        RunnerMessage::Accepted => Ok(link),
        RunnerMessage::Refused { reason } => {
            Err(NodeError::LinkRefused(reason))
        }
        RunnerMessage::Events { .. } | RunnerMessage::Answered { .. } => Err(
            NodeError::MalformedLinkMessage(EVENTS_BEFORE_ANSWER.to_owned()),
        ),
    }
}

fn find_active_runner(run: &Run) -> Option<&DeviceId> {
    run.steps
        .iter()
        .filter(|step| ACTIVE_STEP_STATUSES.contains(&step.status))
        .find_map(|step| step.runner.as_ref())
}

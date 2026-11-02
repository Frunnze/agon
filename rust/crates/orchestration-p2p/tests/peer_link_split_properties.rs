mod link_support;

use link_support::{
    FrameSequence, SecretKeyBytes, arbitrary_frame_sequence, build_runtime,
    local_configuration, localhost_address_of,
};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_p2p::peer_error::PeerError;
use orchestration_p2p::peer_link::PeerLink;
use proptest::prelude::*;

const ACCEPTING_SECRET: SecretKeyBytes = [17; 32];
const CONNECTING_SECRET: SecretKeyBytes = [19; 32];
const SPLIT_PROPERTY_CASES: u32 = 16;

async fn exchange_from_separate_tasks(
    frames: FrameSequence,
) -> Result<FrameSequence, PeerError> {
    let accepting_endpoint =
        PeerEndpoint::bind(local_configuration(ACCEPTING_SECRET)).await?;
    let connecting_endpoint =
        PeerEndpoint::bind(local_configuration(CONNECTING_SECRET)).await?;
    let accepting_address =
        localhost_address_of(accepting_endpoint.peer_address());
    let (accepted_link, connected_link) = tokio::try_join!(
        accepting_endpoint.accept(),
        connecting_endpoint.connect(&accepting_address),
    )?;
    let PeerLink { mut sender, .. } = connected_link;
    let PeerLink {
        mut receiver,
        sender: accepted_sender,
    } = accepted_link;
    let frame_count = frames.len();

    let sending = tokio::spawn(async move {
        for frame in &frames {
            sender.send_frame(frame).await?;
        }
        sender.close().await
    });
    let mut received_frames = Vec::new();
    while received_frames.len() < frame_count {
        let Some(frame) = receiver.receive_frame().await? else {
            break;
        };
        received_frames.push(frame);
    }
    let sent = sending.await.map_err(|_| PeerError::EndpointClosed)?;
    sent?;
    drop(accepted_sender);
    connecting_endpoint.close().await;
    accepting_endpoint.close().await;
    Ok(received_frames)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SPLIT_PROPERTY_CASES))]

    #[test]
    fn test_peer_link_property_halves_work_from_separate_tasks(
        frames in arbitrary_frame_sequence(),
    ) {
        let runtime = build_runtime()?;

        let received =
            runtime.block_on(exchange_from_separate_tasks(frames.clone()))?;

        prop_assert_eq!(received, frames);
    }
}

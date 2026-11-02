mod link_support;

use iroh::SecretKey;
use link_support::{
    FrameSequence, SecretKeyBytes, arbitrary_frame_sequence, build_runtime,
    local_configuration, localhost_address_of,
};
use orchestration_core::device::RunnerLink;
use orchestration_p2p::peer_address::ENDPOINT_PUBLIC_KEY_LENGTH;
use orchestration_p2p::peer_configuration::SECRET_KEY_LENGTH;
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_p2p::peer_error::PeerError;
use orchestration_p2p::peer_link::PeerLink;
use proptest::prelude::*;

const FIXED_SECRET_KEYS: LinkSecretKeys = LinkSecretKeys {
    accepting: [7; SECRET_KEY_LENGTH],
    connecting: [9; SECRET_KEY_LENGTH],
};
const LINK_PROPERTY_CASES: u32 = 32;
const REQUEST_FRAMES: [&[u8]; 3] =
    [b"start run 1", b"", b"stream agent output"];
const REPLY_FRAMES: [&[u8]; 4] =
    [b"accepted", b"working", &[0, 255, 1, 254], b"finished"];

type TestOutcome = Result<(), Box<dyn std::error::Error>>;
type PublicKeyBytes = [u8; ENDPOINT_PUBLIC_KEY_LENGTH];

#[derive(Clone, Copy, Debug)]
struct LinkSecretKeys {
    accepting: SecretKeyBytes,
    connecting: SecretKeyBytes,
}

#[derive(Debug)]
struct FrameExchange {
    received_by_accepting_side: FrameSequence,
    received_by_connecting_side: FrameSequence,
    accepting_link_kind: RunnerLink,
    connecting_link_kind: RunnerLink,
    remote_key_seen_by_accepting_side: PublicKeyBytes,
    remote_key_seen_by_connecting_side: PublicKeyBytes,
    frame_after_connecting_side_closed: Option<Vec<u8>>,
}

fn public_key_of(secret_key: SecretKeyBytes) -> PublicKeyBytes {
    let public_key = SecretKey::from_bytes(&secret_key).public();
    *public_key.as_bytes()
}

fn to_frame_sequence(frames: &[&[u8]]) -> FrameSequence {
    let mut frame_sequence = Vec::new();
    for frame in frames {
        frame_sequence.push(frame.to_vec());
    }
    frame_sequence
}

async fn send_frames(
    link: &mut PeerLink,
    frames: &[Vec<u8>],
) -> Result<(), PeerError> {
    for frame in frames {
        link.sender.send_frame(frame).await?;
    }
    Ok(())
}

async fn receive_frames(
    link: &mut PeerLink,
    frame_count: usize,
) -> Result<FrameSequence, PeerError> {
    let mut received_frames = Vec::new();
    while received_frames.len() < frame_count {
        let Some(frame) = link.receiver.receive_frame().await? else {
            return Ok(received_frames);
        };
        received_frames.push(frame);
    }
    Ok(received_frames)
}

async fn exchange_frames(
    secret_keys: LinkSecretKeys,
    request_frames: &[Vec<u8>],
    reply_frames: &[Vec<u8>],
) -> Result<FrameExchange, PeerError> {
    let accepting_configuration = local_configuration(secret_keys.accepting);
    let accepting_endpoint =
        PeerEndpoint::bind(accepting_configuration).await?;
    let connecting_configuration = local_configuration(secret_keys.connecting);
    let connecting_endpoint =
        PeerEndpoint::bind(connecting_configuration).await?;
    let accepting_address =
        localhost_address_of(accepting_endpoint.peer_address());

    let (mut accepted_link, mut connected_link) = tokio::try_join!(
        accepting_endpoint.accept(),
        connecting_endpoint.connect(&accepting_address),
    )?;

    send_frames(&mut connected_link, request_frames).await?;
    let received_by_accepting_side =
        receive_frames(&mut accepted_link, request_frames.len()).await?;

    send_frames(&mut accepted_link, reply_frames).await?;
    let received_by_connecting_side =
        receive_frames(&mut connected_link, reply_frames.len()).await?;

    let accepting_link_kind = accepted_link.sender.link_kind();
    let connecting_link_kind = connected_link.sender.link_kind();
    let remote_key_seen_by_accepting_side =
        accepted_link.sender.remote_public_key();
    let remote_key_seen_by_connecting_side =
        connected_link.sender.remote_public_key();

    connected_link.sender.close().await?;
    let frame_after_connecting_side_closed =
        accepted_link.receiver.receive_frame().await?;
    accepted_link.sender.close().await?;

    connecting_endpoint.close().await;
    accepting_endpoint.close().await;

    Ok(FrameExchange {
        received_by_accepting_side,
        received_by_connecting_side,
        accepting_link_kind,
        connecting_link_kind,
        remote_key_seen_by_accepting_side,
        remote_key_seen_by_connecting_side,
        frame_after_connecting_side_closed,
    })
}

#[tokio::test(flavor = "multi_thread")]
async fn test_connect_and_accept_exchange_frames_over_a_direct_link()
-> TestOutcome {
    let request_frames = to_frame_sequence(&REQUEST_FRAMES);
    let reply_frames = to_frame_sequence(&REPLY_FRAMES);

    let frame_exchange =
        exchange_frames(FIXED_SECRET_KEYS, &request_frames, &reply_frames)
            .await?;

    assert_eq!(frame_exchange.received_by_accepting_side, request_frames);
    assert_eq!(frame_exchange.received_by_connecting_side, reply_frames);
    assert_eq!(frame_exchange.accepting_link_kind, RunnerLink::Direct);
    assert_eq!(frame_exchange.connecting_link_kind, RunnerLink::Direct);
    assert_eq!(frame_exchange.frame_after_connecting_side_closed, None);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn test_accept_fails_once_the_endpoint_is_closed() -> TestOutcome {
    let configuration = local_configuration(FIXED_SECRET_KEYS.accepting);
    let endpoint = PeerEndpoint::bind(configuration).await?;
    endpoint.close().await;

    let accept_outcome = endpoint.accept().await;

    assert!(matches!(accept_outcome, Err(PeerError::EndpointClosed)));
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LINK_PROPERTY_CASES))]

    #[test]
    fn test_send_frame_property_delivers_frame_sequences_in_order(
        request_frames in arbitrary_frame_sequence(),
        reply_frames in arbitrary_frame_sequence(),
    ) {
        let runtime = build_runtime()?;

        let frame_exchange = runtime.block_on(exchange_frames(
            FIXED_SECRET_KEYS,
            &request_frames,
            &reply_frames,
        ))?;

        prop_assert_eq!(
            frame_exchange.received_by_accepting_side,
            request_frames,
        );
        prop_assert_eq!(
            frame_exchange.received_by_connecting_side,
            reply_frames,
        );
        prop_assert_eq!(
            frame_exchange.frame_after_connecting_side_closed,
            None,
        );
    }

    #[test]
    fn test_link_kind_property_reports_direct_on_a_local_network(
        request_frames in arbitrary_frame_sequence(),
    ) {
        let runtime = build_runtime()?;

        let frame_exchange = runtime.block_on(exchange_frames(
            FIXED_SECRET_KEYS,
            &request_frames,
            &[],
        ))?;

        prop_assert_eq!(
            frame_exchange.accepting_link_kind,
            RunnerLink::Direct,
        );
        prop_assert_eq!(
            frame_exchange.connecting_link_kind,
            RunnerLink::Direct,
        );
    }

    #[test]
    fn test_remote_public_key_property_reports_the_other_side_exactly(
        accepting_secret_key in any::<SecretKeyBytes>(),
        connecting_secret_key in any::<SecretKeyBytes>(),
    ) {
        let accepting_public_key = public_key_of(accepting_secret_key);
        let connecting_public_key = public_key_of(connecting_secret_key);
        prop_assume!(accepting_public_key != connecting_public_key);
        let runtime = build_runtime()?;
        let secret_keys = LinkSecretKeys {
            accepting: accepting_secret_key,
            connecting: connecting_secret_key,
        };

        let frame_exchange =
            runtime.block_on(exchange_frames(secret_keys, &[], &[]))?;

        prop_assert_eq!(
            frame_exchange.remote_key_seen_by_accepting_side,
            connecting_public_key,
        );
        prop_assert_eq!(
            frame_exchange.remote_key_seen_by_connecting_side,
            accepting_public_key,
        );
    }
}

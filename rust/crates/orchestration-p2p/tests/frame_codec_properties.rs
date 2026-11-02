use std::io::ErrorKind;

use orchestration_p2p::frame_codec::{
    FRAME_LENGTH_PREFIX_SIZE, FrameError, MAXIMUM_FRAME_SIZE,
    decode_frame_length, encode_frame_length, read_frame, write_frame,
};
use proptest::prelude::*;
use tokio::runtime::{Builder, Runtime};

const PAYLOAD_SIZE_LIMIT: usize = 2048;
const FRAME_COUNT_LIMIT: usize = 16;
const ARBITRARY_STREAM_SIZE_LIMIT: usize = 512;
const OVERSIZED_PAYLOAD_EXCESS_LIMIT: usize = 64;
const OVERSIZED_PAYLOAD_CASES: u32 = 4;
const LARGEST_PREFIX_LENGTH: usize = u32::MAX as usize;

type FrameReadOutcome = Result<Option<Vec<u8>>, FrameError>;

fn build_runtime() -> Result<Runtime, std::io::Error> {
    Builder::new_current_thread().enable_all().build()
}

fn arbitrary_payload() -> impl Strategy<Value = Vec<u8>> {
    prop::collection::vec(any::<u8>(), 0..PAYLOAD_SIZE_LIMIT)
}

fn arbitrary_frame_sequence() -> impl Strategy<Value = Vec<Vec<u8>>> {
    prop::collection::vec(arbitrary_payload(), 0..FRAME_COUNT_LIMIT)
}

async fn encode_frames(payloads: &[Vec<u8>]) -> Result<Vec<u8>, FrameError> {
    let mut encoded_stream = Vec::new();
    for payload in payloads {
        write_frame(&mut encoded_stream, payload).await?;
    }
    Ok(encoded_stream)
}

async fn decode_frames(
    encoded_stream: &[u8],
) -> Result<Vec<Vec<u8>>, FrameError> {
    let mut remaining_stream = encoded_stream;
    let mut decoded_payloads = Vec::new();
    while let Some(payload) = read_frame(&mut remaining_stream).await? {
        decoded_payloads.push(payload);
    }
    Ok(decoded_payloads)
}

async fn read_every_frame(arbitrary_stream: &[u8]) -> Vec<FrameReadOutcome> {
    let mut remaining_stream = arbitrary_stream;
    let mut read_outcomes = Vec::new();
    loop {
        let read_outcome = read_frame(&mut remaining_stream).await;
        let is_last_outcome = !matches!(read_outcome, Ok(Some(_)));
        read_outcomes.push(read_outcome);
        if is_last_outcome {
            return read_outcomes;
        }
    }
}

fn is_defined_read_outcome(read_outcome: &FrameReadOutcome) -> bool {
    match read_outcome {
        Ok(Some(payload)) => payload.len() <= MAXIMUM_FRAME_SIZE,
        Ok(None) => true,
        Err(FrameError::FrameTooLarge { payload_length }) => {
            *payload_length > MAXIMUM_FRAME_SIZE
        }
        Err(FrameError::Stream(stream_error)) => {
            stream_error.kind() == ErrorKind::UnexpectedEof
        }
    }
}

proptest! {
    #[test]
    fn test_encode_frame_length_property_round_trips_through_decode(
        payload_length in 0..=MAXIMUM_FRAME_SIZE,
    ) {
        let length_prefix = encode_frame_length(payload_length)?;

        let decoded_length = decode_frame_length(length_prefix)?;

        prop_assert_eq!(decoded_length, payload_length);
    }

    #[test]
    fn test_encode_frame_length_property_rejects_oversized_lengths(
        payload_length in (MAXIMUM_FRAME_SIZE + 1)..=usize::MAX,
    ) {
        let encoding_outcome = encode_frame_length(payload_length);

        let is_rejected = matches!(
            encoding_outcome,
            Err(FrameError::FrameTooLarge { payload_length: rejected })
                if rejected == payload_length
        );
        prop_assert!(is_rejected);
    }

    #[test]
    fn test_decode_frame_length_property_reads_big_endian_prefixes(
        payload_length in 0..=MAXIMUM_FRAME_SIZE,
    ) {
        let payload_word = u32::try_from(payload_length)?;
        let length_prefix = payload_word.to_be_bytes();

        let decoded_length = decode_frame_length(length_prefix)?;

        prop_assert_eq!(decoded_length, payload_length);
    }

    #[test]
    fn test_decode_frame_length_property_rejects_oversized_prefixes(
        prefix_length in (MAXIMUM_FRAME_SIZE + 1)..=LARGEST_PREFIX_LENGTH,
    ) {
        let prefix_word = u32::try_from(prefix_length)?;

        let decoding_outcome = decode_frame_length(prefix_word.to_be_bytes());

        let is_rejected = matches!(
            decoding_outcome,
            Err(FrameError::FrameTooLarge { .. })
        );
        prop_assert!(is_rejected);
    }

    #[test]
    fn test_write_frame_property_round_trips_through_read_frame(
        payload in arbitrary_payload(),
    ) {
        let runtime = build_runtime()?;
        let single_frame = vec![payload];

        let encoded_stream = runtime.block_on(encode_frames(&single_frame))?;
        let decoded_payloads =
            runtime.block_on(decode_frames(&encoded_stream))?;

        prop_assert_eq!(decoded_payloads, single_frame);
    }

    #[test]
    fn test_write_frame_property_preserves_frame_sequences_in_order(
        payloads in arbitrary_frame_sequence(),
    ) {
        let runtime = build_runtime()?;

        let encoded_stream = runtime.block_on(encode_frames(&payloads))?;
        let decoded_payloads =
            runtime.block_on(decode_frames(&encoded_stream))?;

        prop_assert_eq!(decoded_payloads, payloads);
    }

    #[test]
    fn test_write_frame_property_puts_length_prefix_before_payload(
        payload in arbitrary_payload(),
    ) {
        let runtime = build_runtime()?;
        let single_frame = vec![payload.clone()];

        let encoded_stream = runtime.block_on(encode_frames(&single_frame))?;
        let (written_prefix, written_payload) =
            encoded_stream.split_at(FRAME_LENGTH_PREFIX_SIZE);
        let expected_prefix = encode_frame_length(payload.len())?;

        prop_assert_eq!(written_prefix, expected_prefix.as_slice());
        prop_assert_eq!(written_payload, payload.as_slice());
    }

    #[test]
    fn test_read_frame_property_rejects_truncated_frames(
        payload in arbitrary_payload(),
        cut_position_seed in any::<usize>(),
    ) {
        let runtime = build_runtime()?;
        let single_frame = vec![payload];
        let encoded_stream = runtime.block_on(encode_frames(&single_frame))?;
        let cut_position = 1 + cut_position_seed % (encoded_stream.len() - 1);
        let truncated_stream = &encoded_stream[..cut_position];

        let decoding_outcome =
            runtime.block_on(decode_frames(truncated_stream));

        let is_rejected = matches!(
            decoding_outcome,
            Err(FrameError::Stream(ref stream_error))
                if stream_error.kind() == ErrorKind::UnexpectedEof
        );
        prop_assert!(is_rejected);
    }

    #[test]
    fn test_read_frame_property_rejects_oversized_prefixes(
        prefix_length in (MAXIMUM_FRAME_SIZE + 1)..=LARGEST_PREFIX_LENGTH,
        trailing_bytes in arbitrary_payload(),
    ) {
        let runtime = build_runtime()?;
        let prefix_word = u32::try_from(prefix_length)?;
        let mut encoded_stream = prefix_word.to_be_bytes().to_vec();
        encoded_stream.extend_from_slice(&trailing_bytes);

        let decoding_outcome =
            runtime.block_on(decode_frames(&encoded_stream));

        let is_rejected = matches!(
            decoding_outcome,
            Err(FrameError::FrameTooLarge { .. })
        );
        prop_assert!(is_rejected);
    }

    #[test]
    fn test_read_frame_property_never_panics_on_arbitrary_bytes(
        arbitrary_stream in prop::collection::vec(
            any::<u8>(),
            0..ARBITRARY_STREAM_SIZE_LIMIT,
        ),
    ) {
        let runtime = build_runtime()?;

        let read_outcomes =
            runtime.block_on(read_every_frame(&arbitrary_stream));

        let every_outcome_is_defined =
            read_outcomes.iter().all(is_defined_read_outcome);
        prop_assert!(every_outcome_is_defined);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(OVERSIZED_PAYLOAD_CASES))]

    #[test]
    fn test_write_frame_property_rejects_oversized_payload_without_writing(
        excess_length in 1..=OVERSIZED_PAYLOAD_EXCESS_LIMIT,
    ) {
        let runtime = build_runtime()?;
        let oversized_payload = vec![0_u8; MAXIMUM_FRAME_SIZE + excess_length];
        let mut written_stream = Vec::new();

        let writing_outcome = runtime.block_on(
            write_frame(&mut written_stream, &oversized_payload),
        );

        let is_rejected = matches!(
            writing_outcome,
            Err(FrameError::FrameTooLarge { .. })
        );
        prop_assert!(is_rejected);
        prop_assert!(written_stream.is_empty());
    }
}

#[test]
fn test_read_frame_returns_none_at_the_end_of_the_stream()
-> Result<(), FrameError> {
    let runtime = build_runtime()?;
    let mut empty_stream: &[u8] = &[];

    let read_outcome = runtime.block_on(read_frame(&mut empty_stream))?;

    assert_eq!(read_outcome, None);
    Ok(())
}

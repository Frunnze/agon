use orchestration_p2p::peer_configuration::{
    PeerConfiguration, RelayChoice, SECRET_KEY_LENGTH,
};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_p2p::peer_error::PeerError;
use orchestration_p2p::record_board::{RecordBoard, RecordFields};
use orchestration_security::peer_addresses::generate_peer_secret;
use tokio::runtime::{Builder, Runtime};

const FIELD_COUNT: usize = 3;
const OVERSIZED_FIELD_COUNT: usize = 12;
const OVERSIZED_FIELD_LENGTH: usize = 200;

type BoardOutcome<Found> = Result<Found, PeerError>;
type SecretKeyBytes = [u8; SECRET_KEY_LENGTH];

fn build_runtime() -> Result<Runtime, std::io::Error> {
    Builder::new_multi_thread().enable_all().build()
}

fn fresh_secret() -> SecretKeyBytes {
    match generate_peer_secret() {
        Ok(secret) => *secret,
        Err(problem) => panic!("a random record key is made: {problem}"),
    }
}

fn sample_fields() -> RecordFields {
    let mut fields = Vec::new();
    for index in 0..FIELD_COUNT {
        fields.push(format!("field-{index}=value {index}"));
    }
    fields
}

fn with_board<Found>(
    use_board: impl AsyncFnOnce(&RecordBoard) -> BoardOutcome<Found>,
) -> BoardOutcome<Found> {
    let runtime = build_runtime().map_err(PeerError::Stream)?;
    runtime.block_on(async {
        let endpoint = PeerEndpoint::bind(PeerConfiguration {
            secret_key: fresh_secret(),
            relay: RelayChoice::Disabled,
        })
        .await?;
        let board = endpoint.open_record_board()?;
        let outcome = use_board(&board).await;
        endpoint.close().await;
        outcome
    })
}

#[test]
fn test_publish_property_a_published_record_reads_back_from_the_board() {
    let secret = fresh_secret();
    let fields = sample_fields();

    let read_back = with_board(async |board| {
        board.publish(&secret, &fields).await?;
        board.read(&secret).await
    });

    let Ok(read_back) = read_back else {
        panic!("the public record board answers: {read_back:?}");
    };
    assert_eq!(read_back, fields);
}

#[test]
fn test_read_property_a_key_nobody_published_reads_as_empty() {
    let never_published = fresh_secret();

    let read_back =
        with_board(async |board| board.read(&never_published).await);

    let Ok(read_back) = read_back else {
        panic!("the public record board answers: {read_back:?}");
    };
    assert!(read_back.is_empty(), "{read_back:?}");
}

#[test]
fn test_publish_property_publishing_no_fields_withdraws_the_record() {
    let secret = fresh_secret();
    let fields = sample_fields();

    let read_back = with_board(async |board| {
        board.publish(&secret, &fields).await?;
        let before = board.read(&secret).await?;
        board.publish(&secret, &[]).await?;
        let after = board.read(&secret).await?;
        Ok((before, after))
    });

    let Ok((before, after)) = read_back else {
        panic!("the public record board answers: {read_back:?}");
    };
    assert_eq!(before, fields);
    assert!(after.is_empty(), "{after:?}");
}

#[test]
fn test_publish_property_an_oversized_record_gives_a_defined_error() {
    let secret = fresh_secret();
    let long_field = "x".repeat(OVERSIZED_FIELD_LENGTH);
    let fields = vec![long_field; OVERSIZED_FIELD_COUNT];

    let published =
        with_board(async |board| board.publish(&secret, &fields).await);

    assert!(
        matches!(published, Err(PeerError::RecordNotBuilt(_))),
        "{published:?}"
    );
}

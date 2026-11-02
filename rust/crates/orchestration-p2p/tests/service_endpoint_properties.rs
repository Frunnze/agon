use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
use std::time::Duration;

use orchestration_p2p::peer_address::{
    PeerAddress, add_same_machine_addresses,
};
use orchestration_p2p::peer_configuration::{
    PeerConfiguration, RelayChoice, SECRET_KEY_LENGTH,
};
use orchestration_p2p::peer_error::PeerError;
use orchestration_p2p::service_endpoint::ServiceEndpoint;
use proptest::prelude::*;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::runtime::{Builder, Runtime};

const SERVICE_PROTOCOL: &[u8] = b"agents-orchestration/test-service/1";
const OTHER_PROTOCOL: &[u8] = b"agents-orchestration/other-service/1";
const SERVING_SECRET: SecretKeyBytes = [21; SECRET_KEY_LENGTH];
const DIALING_SECRET: SecretKeyBytes = [22; SECRET_KEY_LENGTH];
const EXCHANGE_CASES: u32 = 8;
const PAYLOAD_LIMIT: usize = 64 * 1024;
const DIRECT_ADDRESS_LIMIT: usize = 6;
const EXCHANGE_LIMIT: Duration = Duration::from_secs(20);

type Outcome = Result<Vec<u8>, PeerError>;
type SecretKeyBytes = [u8; SECRET_KEY_LENGTH];

fn build_runtime() -> Result<Runtime, std::io::Error> {
    Builder::new_multi_thread().enable_all().build()
}

fn local_configuration(secret_key: SecretKeyBytes) -> PeerConfiguration {
    PeerConfiguration {
        secret_key,
        relay: RelayChoice::Disabled,
    }
}

fn localhost_address_of(peer_address: PeerAddress) -> PeerAddress {
    let mut localhost_addresses = Vec::new();
    for direct_address in &peer_address.direct_addresses {
        if direct_address.is_ipv4() {
            let port = direct_address.port();
            localhost_addresses
                .push(SocketAddr::from((Ipv4Addr::LOCALHOST, port)));
        }
    }
    PeerAddress {
        direct_addresses: localhost_addresses,
        ..peer_address
    }
}

async fn echo_one_stream(serving: &ServiceEndpoint) -> Result<(), PeerError> {
    let connection = serving.accept().await?;
    let mut stream = connection.accept_stream().await?;
    let mut received = Vec::new();
    stream
        .read_to_end(&mut received)
        .await
        .map_err(PeerError::Stream)?;
    stream
        .write_all(&received)
        .await
        .map_err(PeerError::Stream)?;
    stream.shutdown().await.map_err(PeerError::Stream)?;
    connection.closed().await;
    Ok(())
}

async fn exchange_payload(
    payload: Vec<u8>,
    protocol: &'static [u8],
) -> Outcome {
    let serving = ServiceEndpoint::bind(
        local_configuration(SERVING_SECRET),
        vec![SERVICE_PROTOCOL.to_vec()],
    )
    .await?;
    let dialing =
        ServiceEndpoint::bind(local_configuration(DIALING_SECRET), Vec::new())
            .await?;
    let serving_address = localhost_address_of(serving.peer_address());

    let echoing = echo_one_stream(&serving);
    let dialing_side = async {
        let connection = dialing.connect(&serving_address, protocol).await?;
        let mut stream = connection.open_stream().await?;
        stream
            .write_all(&payload)
            .await
            .map_err(PeerError::Stream)?;
        stream.shutdown().await.map_err(PeerError::Stream)?;
        let mut answer = Vec::new();
        stream
            .read_to_end(&mut answer)
            .await
            .map_err(PeerError::Stream)?;
        connection.close();
        Ok(answer)
    };
    let (echoed, answer) = tokio::join!(echoing, dialing_side);
    dialing.close().await;
    serving.close().await;
    echoed?;
    answer
}

fn run_exchange(payload: Vec<u8>, protocol: &'static [u8]) -> Outcome {
    let runtime = build_runtime().map_err(PeerError::Stream)?;
    runtime.block_on(async {
        tokio::time::timeout(
            EXCHANGE_LIMIT,
            exchange_payload(payload, protocol),
        )
        .await
        .map_err(|_| PeerError::EndpointClosed)?
    })
}

fn direct_address_strategy() -> impl Strategy<Value = Vec<SocketAddr>> {
    let address =
        (any::<[u8; 4]>(), 1..u16::MAX).prop_map(|(octets, port)| {
            SocketAddr::from((Ipv4Addr::from(octets), port))
        });
    prop::collection::vec(address, 0..DIRECT_ADDRESS_LIMIT)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(EXCHANGE_CASES))]

    #[test]
    fn test_connect_property_a_stream_carries_bytes_both_ways(
        payload in prop::collection::vec(any::<u8>(), 0..PAYLOAD_LIMIT),
    ) {
        let answer = run_exchange(payload.clone(), SERVICE_PROTOCOL);

        let answer_text = answer.map_err(|error| error.to_string());
        prop_assert_eq!(answer_text, Ok(payload));
    }

    #[test]
    fn test_add_same_machine_addresses_property_each_port_gets_loopback(
        direct_addresses in direct_address_strategy(),
    ) {
        let address = PeerAddress {
            endpoint_public_key: [3; 32],
            direct_addresses: direct_addresses.clone(),
            relay_url: None,
        };

        let extended = add_same_machine_addresses(address.clone());
        let extended_twice = add_same_machine_addresses(extended.clone());

        for direct_address in &direct_addresses {
            prop_assert!(extended.direct_addresses.contains(direct_address));
            let loopback = SocketAddr::new(
                IpAddr::V4(Ipv4Addr::LOCALHOST),
                direct_address.port(),
            );
            prop_assert!(extended.direct_addresses.contains(&loopback));
        }
        prop_assert_eq!(&extended_twice, &extended);
        let kept_key = extended.endpoint_public_key;
        prop_assert_eq!(kept_key, address.endpoint_public_key);
    }
}

#[test]
fn test_connect_property_an_unaccepted_protocol_is_refused() {
    let answer = run_exchange(b"hello".to_vec(), OTHER_PROTOCOL);

    assert!(answer.is_err(), "{answer:?}");
}

#[test]
fn test_add_same_machine_addresses_property_ipv6_gets_ipv6_loopback() {
    let ipv6_address = SocketAddr::new(IpAddr::V6(Ipv6Addr::UNSPECIFIED), 9);
    let address = PeerAddress {
        endpoint_public_key: [4; 32],
        direct_addresses: vec![ipv6_address],
        relay_url: None,
    };

    let extended = add_same_machine_addresses(address);

    let loopback = SocketAddr::new(IpAddr::V6(Ipv6Addr::LOCALHOST), 9);
    assert!(extended.direct_addresses.contains(&loopback));
}

use std::net::{IpAddr, SocketAddr};

use iroh::SecretKey;
use orchestration_p2p::peer_address::PeerAddress;
use orchestration_p2p::peer_configuration::{
    PeerConfiguration, RelayChoice, SECRET_KEY_LENGTH,
};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_p2p::peer_error::PeerError;
use proptest::prelude::*;
use tokio::runtime::{Builder, Runtime};

const DIRECT_ADDRESS_COUNT_LIMIT: usize = 8;
const ENDPOINT_PROPERTY_CASES: u32 = 16;
const UNPARSABLE_RELAY_PATTERN: &str = "[a-z ]{0,24}";
const RELAY_URL_PATTERN: &str = "https://[a-z]{1,12}\\.example\\.org/";

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

type PeerAddressParts = ([u8; 32], Vec<SocketAddr>, Option<String>);

fn assemble_peer_address(parts: PeerAddressParts) -> PeerAddress {
    let (endpoint_public_key, direct_addresses, relay_url) = parts;
    PeerAddress {
        endpoint_public_key,
        direct_addresses,
        relay_url,
    }
}

fn arbitrary_peer_address() -> impl Strategy<Value = PeerAddress> {
    let direct_address = any::<(IpAddr, u16)>().prop_map(SocketAddr::from);
    let direct_addresses =
        prop::collection::vec(direct_address, 0..DIRECT_ADDRESS_COUNT_LIMIT);
    let relay_url = prop::option::of(RELAY_URL_PATTERN);
    (any::<[u8; 32]>(), direct_addresses, relay_url)
        .prop_map(assemble_peer_address)
}

async fn describe_bound_endpoint(
    secret_key: SecretKeyBytes,
) -> Result<PeerAddress, PeerError> {
    let endpoint = PeerEndpoint::bind(local_configuration(secret_key)).await?;
    let peer_address = endpoint.peer_address();
    endpoint.close().await;
    Ok(peer_address)
}

async fn connect_to_address(
    secret_key: SecretKeyBytes,
    peer_address: &PeerAddress,
) -> Result<(), PeerError> {
    let endpoint = PeerEndpoint::bind(local_configuration(secret_key)).await?;
    let connect_outcome = endpoint.connect(peer_address).await;
    endpoint.close().await;
    connect_outcome.map(|_| ())
}

async fn bind_with_relay(relay: RelayChoice) -> Result<(), PeerError> {
    let configuration = PeerConfiguration {
        secret_key: [0; SECRET_KEY_LENGTH],
        relay,
    };
    let endpoint = PeerEndpoint::bind(configuration).await?;
    endpoint.close().await;
    Ok(())
}

proptest! {
    #[test]
    fn test_peer_address_property_round_trips_through_json(
        peer_address in arbitrary_peer_address(),
    ) {
        let encoded_address = serde_json::to_string(&peer_address)?;

        let decoded_address: PeerAddress =
            serde_json::from_str(&encoded_address)?;

        prop_assert_eq!(decoded_address, peer_address);
    }

    #[test]
    fn test_peer_address_property_rejects_arbitrary_json_without_panic(
        arbitrary_text in ".{0,64}",
    ) {
        let decoding_outcome =
            serde_json::from_str::<PeerAddress>(&arbitrary_text);

        prop_assert!(decoding_outcome.is_err());
    }

    #[test]
    fn test_bind_property_rejects_unparsable_custom_relay(
        relay_text in UNPARSABLE_RELAY_PATTERN,
    ) {
        let runtime = build_runtime()?;

        let bind_outcome =
            runtime.block_on(bind_with_relay(RelayChoice::Custom(relay_text)));

        let is_rejected =
            matches!(bind_outcome, Err(PeerError::InvalidRelayUrl { .. }));
        prop_assert!(is_rejected);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ENDPOINT_PROPERTY_CASES))]

    #[test]
    fn test_peer_address_property_carries_public_key_of_secret_key(
        secret_key in any::<SecretKeyBytes>(),
    ) {
        let runtime = build_runtime()?;
        let expected_public_key = SecretKey::from_bytes(&secret_key).public();

        let peer_address =
            runtime.block_on(describe_bound_endpoint(secret_key))?;

        prop_assert_eq!(
            &peer_address.endpoint_public_key,
            expected_public_key.as_bytes(),
        );
    }

    #[test]
    fn test_peer_address_property_lists_direct_addresses_without_relay(
        secret_key in any::<SecretKeyBytes>(),
    ) {
        let runtime = build_runtime()?;

        let peer_address =
            runtime.block_on(describe_bound_endpoint(secret_key))?;

        prop_assert!(!peer_address.direct_addresses.is_empty());
        prop_assert_eq!(peer_address.relay_url, None);
    }

    #[test]
    fn test_connect_property_rejects_unparsable_relay_url(
        secret_key in any::<SecretKeyBytes>(),
        remote_secret_key in any::<SecretKeyBytes>(),
        relay_text in UNPARSABLE_RELAY_PATTERN,
    ) {
        let runtime = build_runtime()?;
        let remote_public_key =
            SecretKey::from_bytes(&remote_secret_key).public();
        let peer_address = PeerAddress {
            endpoint_public_key: *remote_public_key.as_bytes(),
            direct_addresses: Vec::new(),
            relay_url: Some(relay_text),
        };

        let connect_outcome =
            runtime.block_on(connect_to_address(secret_key, &peer_address));

        let is_rejected =
            matches!(connect_outcome, Err(PeerError::InvalidRelayUrl { .. }));
        prop_assert!(is_rejected);
    }

    #[test]
    fn test_connect_property_fails_without_any_route(
        secret_key in any::<SecretKeyBytes>(),
        remote_public_key in any::<[u8; 32]>(),
    ) {
        let runtime = build_runtime()?;
        let peer_address = PeerAddress {
            endpoint_public_key: remote_public_key,
            direct_addresses: Vec::new(),
            relay_url: None,
        };

        let connect_outcome =
            runtime.block_on(connect_to_address(secret_key, &peer_address));

        let is_rejected = matches!(
            connect_outcome,
            Err(PeerError::InvalidPublicKey(_) | PeerError::Connect(_))
        );
        prop_assert!(is_rejected);
    }
}

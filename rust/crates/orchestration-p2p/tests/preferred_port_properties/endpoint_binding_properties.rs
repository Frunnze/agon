use std::collections::BTreeSet;

use orchestration_p2p::peer_address::ENDPOINT_PUBLIC_KEY_LENGTH;
use orchestration_p2p::peer_error::PeerError;
use orchestration_p2p::service_endpoint::ServiceEndpoint;
use proptest::prelude::*;

use crate::link_support::{SecretKeyBytes, local_configuration};
use crate::port_support::{
    ANY_FREE_PORT, SERVICE_PROTOCOL, bind_serving_on, list_ipv4_ports,
    run_bounded, take_udp_port,
};

const BINDING_CASES: u32 = 6;
const LIVE_ENDPOINT_LIMIT: usize = 5;

type EndpointKey = [u8; ENDPOINT_PUBLIC_KEY_LENGTH];

async fn bind_any(
    secret_key: SecretKeyBytes,
) -> Result<ServiceEndpoint, PeerError> {
    ServiceEndpoint::bind(
        local_configuration(secret_key),
        vec![SERVICE_PROTOCOL.to_vec()],
    )
    .await
}

async fn read_key_of_bind(
    secret_key: SecretKeyBytes,
) -> Result<EndpointKey, PeerError> {
    let endpoint = bind_any(secret_key).await?;
    let endpoint_key = endpoint.peer_address().endpoint_public_key;
    endpoint.close().await;
    Ok(endpoint_key)
}

async fn read_key_of_preferring_bind(
    secret_key: SecretKeyBytes,
    preferred_port: u16,
) -> Result<EndpointKey, PeerError> {
    let endpoint = bind_serving_on(secret_key, preferred_port).await?;
    let endpoint_key = endpoint.peer_address().endpoint_public_key;
    endpoint.close().await;
    Ok(endpoint_key)
}

async fn describe_bound_ports(
    secret_key: SecretKeyBytes,
) -> Result<(u16, Vec<u16>), PeerError> {
    let endpoint = bind_any(secret_key).await?;
    let bound_port = endpoint.bound_ipv4_port()?;
    let address_ports = list_ipv4_ports(&endpoint.peer_address());
    endpoint.close().await;
    Ok((bound_port, address_ports))
}

async fn bind_live_endpoints(
    secret_keys: Vec<SecretKeyBytes>,
) -> Result<Vec<u16>, PeerError> {
    let mut endpoints = Vec::new();
    for secret_key in secret_keys {
        endpoints.push(bind_any(secret_key).await?);
    }
    let mut bound_ports = Vec::new();
    for endpoint in &endpoints {
        bound_ports.push(endpoint.bound_ipv4_port()?);
    }
    for endpoint in &endpoints {
        endpoint.close().await;
    }
    Ok(bound_ports)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(BINDING_CASES))]

    #[test]
    fn test_service_endpoint_bind_property_the_key_follows_the_secret(
        first_secret in any::<SecretKeyBytes>(),
        second_secret in any::<SecretKeyBytes>(),
    ) {
        prop_assume!(first_secret != second_secret);

        let first_key = run_bounded(read_key_of_bind(first_secret))
            .map_err(TestCaseError::fail)?;
        let first_key_again = run_bounded(read_key_of_bind(first_secret))
            .map_err(TestCaseError::fail)?;
        let second_key = run_bounded(read_key_of_bind(second_secret))
            .map_err(TestCaseError::fail)?;

        prop_assert_eq!(first_key, first_key_again);
        prop_assert_ne!(first_key, second_key);
    }

    #[test]
    fn test_service_endpoint_bind_property_the_address_names_the_port(
        secret_key in any::<SecretKeyBytes>(),
    ) {
        let (bound_port, address_ports) =
            run_bounded(describe_bound_ports(secret_key))
                .map_err(TestCaseError::fail)?;

        prop_assert_ne!(bound_port, ANY_FREE_PORT);
        prop_assert!(!address_ports.is_empty());
        for address_port in address_ports {
            prop_assert_eq!(address_port, bound_port);
        }
    }

    #[test]
    fn test_service_endpoint_bind_property_live_endpoints_never_share_ports(
        secret_keys in prop::collection::vec(
            any::<SecretKeyBytes>(),
            2..LIVE_ENDPOINT_LIMIT,
        ),
    ) {
        let endpoint_count = secret_keys.len();

        let bound_ports = run_bounded(bind_live_endpoints(secret_keys))
            .map_err(TestCaseError::fail)?;

        let distinct_ports: BTreeSet<u16> =
            bound_ports.iter().copied().collect();
        prop_assert_eq!(distinct_ports.len(), endpoint_count);
    }

    #[test]
    fn test_bind_preferring_ipv4_port_property_the_key_follows_the_secret(
        secret_key in any::<SecretKeyBytes>(),
        is_port_taken in any::<bool>(),
    ) {
        let (taken, taken_port) =
            take_udp_port().map_err(TestCaseError::fail)?;
        let preferred_port = if is_port_taken {
            taken_port
        } else {
            ANY_FREE_PORT
        };

        let preferring_key = run_bounded(read_key_of_preferring_bind(
            secret_key,
            preferred_port,
        ))
        .map_err(TestCaseError::fail)?;
        drop(taken);
        let plain_key = run_bounded(read_key_of_bind(secret_key))
            .map_err(TestCaseError::fail)?;

        prop_assert_eq!(preferring_key, plain_key);
    }
}

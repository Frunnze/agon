use orchestration_p2p::peer_error::PeerError;
use proptest::prelude::*;

use crate::link_support::SecretKeyBytes;
use crate::port_support::{
    ANY_FREE_PORT, bind_serving_on, echo_through, find_free_udp_port,
    list_ipv4_ports, run_bounded, take_udp_port,
};

const PORT_CASES: u32 = 6;
const RESTART_LIMIT: usize = 4;
const PAYLOAD_LIMIT: usize = 4096;

type BoundPorts = (u16, Vec<u16>);

async fn bind_and_describe(
    secret_key: SecretKeyBytes,
    preferred_port: u16,
) -> Result<BoundPorts, PeerError> {
    let serving = bind_serving_on(secret_key, preferred_port).await?;
    let bound_port = serving.bound_ipv4_port()?;
    let address_ports = list_ipv4_ports(&serving.peer_address());
    serving.close().await;
    Ok((bound_port, address_ports))
}

fn restart_again_and_again(
    secret_key: SecretKeyBytes,
    restart_count: usize,
) -> Result<Vec<u16>, String> {
    let first_start = bind_and_describe(secret_key, ANY_FREE_PORT);
    let (first_port, _) = run_bounded(first_start)?;
    let mut bound_ports = vec![first_port];
    for _ in 0..restart_count {
        let restart = bind_and_describe(secret_key, first_port);
        let (again_port, _) = run_bounded(restart)?;
        bound_ports.push(again_port);
    }
    Ok(bound_ports)
}

async fn echo_beside_a_taken_port(
    serving_secret: SecretKeyBytes,
    dialing_secret: SecretKeyBytes,
    taken_port: u16,
    payload: Vec<u8>,
) -> Result<(u16, Vec<u8>), PeerError> {
    let serving = bind_serving_on(serving_secret, taken_port).await?;
    let bound_port = serving.bound_ipv4_port()?;
    let answer = echo_through(&serving, dialing_secret, &payload).await;
    serving.close().await;
    Ok((bound_port, answer?))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PORT_CASES))]

    #[test]
    fn test_bind_preferring_ipv4_port_property_a_free_port_is_used(
        secret_key in any::<SecretKeyBytes>(),
    ) {
        let free_port = find_free_udp_port().map_err(TestCaseError::fail)?;

        let (bound_port, address_ports) =
            run_bounded(bind_and_describe(secret_key, free_port))
                .map_err(TestCaseError::fail)?;

        prop_assert_eq!(bound_port, free_port);
        prop_assert!(!address_ports.is_empty());
        for address_port in address_ports {
            prop_assert_eq!(address_port, free_port);
        }
    }

    #[test]
    fn test_bind_preferring_ipv4_port_property_a_taken_port_falls_back(
        secret_key in any::<SecretKeyBytes>(),
    ) {
        let (taken, taken_port) =
            take_udp_port().map_err(TestCaseError::fail)?;

        let (bound_port, address_ports) =
            run_bounded(bind_and_describe(secret_key, taken_port))
                .map_err(TestCaseError::fail)?;
        drop(taken);

        prop_assert_ne!(bound_port, taken_port);
        prop_assert_ne!(bound_port, ANY_FREE_PORT);
        for address_port in address_ports {
            prop_assert_eq!(address_port, bound_port);
        }
    }

    #[test]
    fn test_bind_preferring_ipv4_port_property_the_fallback_still_serves(
        serving_secret in any::<SecretKeyBytes>(),
        dialing_secret in any::<SecretKeyBytes>(),
        payload in prop::collection::vec(any::<u8>(), 0..PAYLOAD_LIMIT),
    ) {
        prop_assume!(serving_secret != dialing_secret);
        let (taken, taken_port) =
            take_udp_port().map_err(TestCaseError::fail)?;

        let (bound_port, answer) = run_bounded(echo_beside_a_taken_port(
            serving_secret,
            dialing_secret,
            taken_port,
            payload.clone(),
        ))
        .map_err(TestCaseError::fail)?;
        drop(taken);

        prop_assert_ne!(bound_port, taken_port);
        prop_assert_eq!(answer, payload);
    }

    #[test]
    fn test_bind_preferring_ipv4_port_property_a_restart_keeps_the_port(
        secret_key in any::<SecretKeyBytes>(),
        restart_count in 1..RESTART_LIMIT,
    ) {
        let bound_ports = restart_again_and_again(secret_key, restart_count)
            .map_err(TestCaseError::fail)?;

        prop_assert_eq!(bound_ports.len(), restart_count + 1);
        let first_port = bound_ports[0];
        prop_assert_ne!(first_port, ANY_FREE_PORT);
        for bound_port in bound_ports {
            prop_assert_eq!(bound_port, first_port);
        }
    }
}

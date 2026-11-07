use std::net::{Ipv4Addr, SocketAddr, TcpListener, TcpStream};
use std::time::Duration;

use proptest::prelude::*;
use serde_json::Value;

use crate::hosting_desk::{
    heavy_cases, host_a_server, keep_data_in_target, read_loopback_health,
    shared_hosting,
};
use crate::support::hosting_steps::{
    HEALTHY_ANSWER_START, create_hosted_account, find_local_network_address,
    hosted_server_files, pick_free_port, read_status,
};
use crate::support::test_device::{TestDevice, fail};

const PORT_REFUSAL_START: &str = "the app server cannot listen on port ";
const PORT_TAKEN_TEXT: &str = "already in use";
const OUTSIDE_CONNECT_LIMIT: Duration = Duration::from_secs(3);

#[derive(Debug)]
struct TakenPort {
    port: u16,
    device: TestDevice,
    occupier: TcpListener,
}

fn take_a_port() -> Result<TakenPort, TestCaseError> {
    keep_data_in_target().map_err(fail)?;
    let port = pick_free_port().map_err(fail)?;
    let occupier =
        TcpListener::bind((Ipv4Addr::LOCALHOST, port)).map_err(fail)?;
    let device = TestDevice::start_hosting_on(port).map_err(fail)?;
    Ok(TakenPort {
        port,
        device,
        occupier,
    })
}

fn read_refusal(device: &TestDevice) -> Result<String, TestCaseError> {
    match create_hosted_account(device) {
        Ok(account) => Err(fail(format!("hosting succeeded: {account}"))),
        Err(problem) => Ok(problem),
    }
}

proptest! {
    #![proptest_config(heavy_cases(2))]

    #[test]
    fn test_bind_hosted_listener_property_answers_health_on_the_chosen_port(
        request_count in 1_usize..4,
    ) {
        let hosting = host_a_server().map_err(fail)?;

        for _ in 0..request_count {
            let answer = read_loopback_health(hosting.port).map_err(fail)?;
            prop_assert!(answer.starts_with(HEALTHY_ANSWER_START), "{answer}");
        }
    }

    #[test]
    fn test_bind_hosted_listener_property_listens_on_loopback_only(
        attempt_count in 1_usize..3,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let network_address = find_local_network_address().map_err(fail)?;

        for _ in 0..attempt_count {
            let outside = SocketAddr::new(network_address, hosting.port);
            let connected =
                TcpStream::connect_timeout(&outside, OUTSIDE_CONNECT_LIMIT);
            prop_assert!(connected.is_err());
        }
    }

    #[test]
    fn test_bind_hosted_listener_property_a_freed_port_hosts_after_refusal(
        refusal_count in 1_usize..3,
    ) {
        let taken = take_a_port()?;

        for _ in 0..refusal_count {
            read_refusal(&taken.device)?;
            let present: Vec<_> = hosted_server_files(&taken.device)
                .into_iter()
                .filter(|path| path.exists())
                .collect();
            prop_assert!(present.is_empty(), "{present:?}");
        }
        drop(taken.occupier);
        let hosted = create_hosted_account(&taken.device);
        let answer = read_loopback_health(taken.port);

        prop_assert!(hosted.is_ok(), "{hosted:?}");
        let answer = answer.map_err(fail)?;
        prop_assert!(answer.starts_with(HEALTHY_ANSWER_START), "{answer}");
    }

    #[test]
    fn test_describe_unavailable_port_property_names_the_port(
        _round in 0_u8..3,
    ) {
        let taken = take_a_port()?;

        let refusal = read_refusal(&taken.device)?;

        let expected_start = format!("{PORT_REFUSAL_START}{}: ", taken.port);
        prop_assert!(refusal.starts_with(&expected_start), "{refusal}");
    }

    #[test]
    fn test_describe_unavailable_port_property_carries_the_system_reason(
        _round in 0_u8..3,
    ) {
        let taken = take_a_port()?;

        let refusal = read_refusal(&taken.device)?;

        let reason = refusal.split_once(": ").map(|(_, reason)| reason);
        let reason = reason.unwrap_or_default().to_lowercase();
        prop_assert!(reason.contains(PORT_TAKEN_TEXT), "{refusal}");
    }

    #[test]
    fn test_describe_unavailable_port_property_repeats_the_same_refusal(
        attempt_count in 2_usize..5,
    ) {
        let taken = take_a_port()?;

        let first = read_refusal(&taken.device)?;
        for _ in 1..attempt_count {
            let again = read_refusal(&taken.device)?;
            prop_assert_eq!(&again, &first);
        }
        let status = read_status(&taken.device).map_err(fail)?;

        prop_assert_eq!(&status["hosted_server_address"], &Value::Null);
    }
}

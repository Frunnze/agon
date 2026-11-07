use std::time::{Duration, Instant};

use orchestration_p2p::board_retry::BOARD_RETRY_PAUSES;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::approver_desk::{
    APPROVED_STATE, ApproverDesk, read_request, start_pairing,
};
use crate::at_once::run_at_once;
use crate::board_refusal::{
    ProxiedDevice, RefusingProxy, count_attempts_per_publish,
};
use crate::command_device::CommandDevice;
use crate::support::pairing_steps::JOINING_NAME;
use crate::support::test_device::{fail, read_text};

const BOARD_CASES: u32 = 2;
const FEWEST_THREADS: usize = 2;
const MOST_THREADS: usize = 3;
const MOST_STARTS: usize = 2;
const JOINING_ROLE: &str = "client";
const REFUSAL_SLACK: Duration = Duration::from_secs(5);

fn join_proxied_device(
    desk: &ApproverDesk,
    proxy: &RefusingProxy,
) -> Result<ProxiedDevice, String> {
    let joining_device = ProxiedDevice::start(proxy)?;
    let session = start_pairing(&desk.approver)?;
    joining_device.run(&json!({
        "command": "join_with_code",
        "server_address": desk.server.address,
        "code": read_text(&session, "/display_code")?,
        "device_name": JOINING_NAME,
        "role": JOINING_ROLE,
    }))?;
    read_request(&desk.approver, &session["code"])?;
    desk.approve(&desk.approver, &session["code"])?;
    let join_status =
        joining_device.run(&json!({ "command": "join_status" }))?;
    if join_status["state"] != json!(APPROVED_STATE) {
        return Err(format!("the join ended as {join_status}"));
    }
    Ok(joining_device)
}

fn longest_refused_start() -> Duration {
    let mut retry_pauses = Duration::ZERO;
    for pause in BOARD_RETRY_PAUSES {
        retry_pauses += pause;
    }
    retry_pauses + REFUSAL_SLACK
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(BOARD_CASES))]

    #[test]
    fn test_find_public_server_address_property_a_joined_device_asks_too(
        start_count in 1..=MOST_STARTS,
    ) {
        let proxy = RefusingProxy::start().map_err(fail)?;
        let desk = ApproverDesk::open().map_err(fail)?;
        let joined_device =
            join_proxied_device(&desk, &proxy).map_err(fail)?;
        let attempts_before = proxy.count_board_attempts().map_err(fail)?;

        for _ in 0..start_count {
            start_pairing(&joined_device).map_err(fail)?;
        }
        let attempts_after = proxy.count_board_attempts().map_err(fail)?;

        prop_assert_eq!(attempts_before, 0);
        prop_assert_eq!(
            attempts_after,
            start_count * count_attempts_per_publish()
        );
    }

    #[test]
    fn test_find_public_server_address_property_starts_at_once_all_ask(
        thread_count in FEWEST_THREADS..=MOST_THREADS,
    ) {
        let proxy = RefusingProxy::start().map_err(fail)?;
        let device = ProxiedDevice::start(&proxy).map_err(fail)?;
        let desk = ApproverDesk::open_with(device).map_err(fail)?;

        let starting = || start_pairing(&desk.approver);
        let started = run_at_once(thread_count, &starting);
        let attempts_after = proxy.count_board_attempts().map_err(fail)?;

        for session in started {
            let session = session.map_err(fail)?;
            prop_assert_ne!(&session["rendezvous_problem"], &Value::Null);
        }
        prop_assert_eq!(
            attempts_after,
            thread_count * count_attempts_per_publish()
        );
    }

    #[test]
    fn test_publish_server_for_code_property_a_refusal_ends_within_retries(
        start_count in 1..=MOST_STARTS,
    ) {
        let proxy = RefusingProxy::start().map_err(fail)?;
        let device = ProxiedDevice::start(&proxy).map_err(fail)?;
        let desk = ApproverDesk::open_with(device).map_err(fail)?;

        for _ in 0..start_count {
            let started_at = Instant::now();
            let session = start_pairing(&desk.approver).map_err(fail)?;
            let start_duration = started_at.elapsed();

            prop_assert!(
                start_duration <= longest_refused_start(),
                "{:?}",
                start_duration
            );
            prop_assert_ne!(&session["rendezvous_problem"], &Value::Null);
        }
    }
}

use std::sync::Mutex;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::approver_desk::{
    ApproverDesk, DESK_CASES, PairingEnding, read_status_problem,
    start_pairing,
};
use crate::at_once::{run_at_once, run_both_at_once};
use crate::command_device::crossing_relay_choices;
use crate::pairing_actions::NO_PEER_ENDPOINT;
use crate::support::test_device::fail;

const FEWEST_THREADS: usize = 2;
const MOST_THREADS: usize = 4;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DESK_CASES))]

    #[test]
    fn test_lock_state_property_starts_at_once_all_name_the_failure(
        peer_relay in crossing_relay_choices(),
        thread_count in FEWEST_THREADS..=MOST_THREADS,
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;

        let starting = || start_pairing(&desk.approver);
        let started = run_at_once(thread_count, &starting);
        let status_problem =
            read_status_problem(&desk.approver).map_err(fail)?;

        for session in started {
            let session = session.map_err(fail)?;
            prop_assert_eq!(
                &session["rendezvous_problem"],
                &json!(NO_PEER_ENDPOINT)
            );
        }
        prop_assert_eq!(status_problem, json!(NO_PEER_ENDPOINT));
    }

    #[test]
    fn test_lock_state_property_status_reads_during_starts_stay_defined(
        peer_relay in crossing_relay_choices(),
        round_count in 1..=MOST_THREADS,
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let defined_problems = [Value::Null, json!(NO_PEER_ENDPOINT)];

        let starting = || start_pairing(&desk.approver);
        let reading = || read_status_problem(&desk.approver);
        for _ in 0..round_count {
            let (started, read_during_start) =
                run_both_at_once(&starting, &reading);
            let read_after_start =
                read_status_problem(&desk.approver).map_err(fail)?;

            let problem_during_start = read_during_start.map_err(fail)?;
            prop_assert!(started.is_ok(), "{:?}", started);
            prop_assert!(defined_problems.contains(&problem_during_start));
            prop_assert_eq!(read_after_start, json!(NO_PEER_ENDPOINT));
        }
    }

    #[test]
    fn test_lock_state_property_cancels_at_once_clear_the_failure(
        peer_relay in crossing_relay_choices(),
        code_count in FEWEST_THREADS..=MOST_THREADS,
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let mut codes = Vec::new();
        for _ in 0..code_count {
            let session = start_pairing(&desk.approver).map_err(fail)?;
            codes.push(session["code"].clone());
        }

        let codes_left = Mutex::new(codes);
        let cancelling = || desk.end_next(&codes_left, PairingEnding::Cancel);
        let cancelled = run_at_once(code_count, &cancelling);
        let status_problem =
            read_status_problem(&desk.approver).map_err(fail)?;

        for cancel_outcome in cancelled {
            prop_assert_eq!(cancel_outcome, Ok(Value::Null));
        }
        prop_assert_eq!(status_problem, Value::Null);
    }
}

use std::sync::Mutex;

use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::approver_desk::{
    ApproverDesk, DESK_CASES, JoinedPairing, NOT_STARTED_HERE, PairingEnding,
    open_desk_or_panic, pairing_endings, read_join_state, read_request,
    read_status_problem, start_pairing,
};
use crate::at_once::run_at_once;
use crate::command_device::crossing_relay_choices;
use crate::pairing_actions::NO_PEER_ENDPOINT;
use crate::support::test_device::fail;

const NOBODY_JOINED: &str = "nobody has entered the pairing code yet";
const FEWEST_CODES: usize = 2;
const MOST_CODES: usize = 3;
const MOST_READS_BEFORE_RESTART: usize = 2;

#[test]
fn test_withdraw_when_published_property_an_early_ending_leaves_no_problem() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&pairing_endings(), |ending| {
        let session = start_pairing(&desk.approver).map_err(fail)?;
        let code = session["code"].clone();

        let ended = desk.end(&desk.approver, ending, &code);
        let status_problem =
            read_status_problem(&desk.approver).map_err(fail)?;
        let read_after_ending = read_request(&desk.approver, &code);

        prop_assert_eq!(status_problem, Value::Null);
        match ending {
            PairingEnding::Approve => {
                prop_assert_eq!(ended, Err(NOBODY_JOINED.to_owned()));
                let still_waiting = read_after_ending.map_err(fail)?;
                prop_assert_eq!(&still_waiting["joining"], &Value::Null);
            }
            PairingEnding::Cancel | PairingEnding::Reject => {
                prop_assert_eq!(ended, Ok(Value::Null));
                prop_assert!(read_after_ending.is_err());
            }
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_withdraw_when_published_property_codes_ended_at_once_all_end() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));
    let endings_at_once = (pairing_endings(), FEWEST_CODES..=MOST_CODES);

    let outcome = runner.run(&endings_at_once, |(ending, code_count)| {
        let mut joined_pairings: Vec<JoinedPairing> = Vec::new();
        let mut codes = Vec::new();
        for _ in 0..code_count {
            let joined = desk.start_and_join().map_err(fail)?;
            read_request(&desk.approver, &joined.session["code"])
                .map_err(fail)?;
            codes.push(joined.session["code"].clone());
            joined_pairings.push(joined);
        }

        let codes_left = Mutex::new(codes);
        let ending_task = || desk.end_next(&codes_left, ending);
        let endings = run_at_once(code_count, &ending_task);
        let status_problem =
            read_status_problem(&desk.approver).map_err(fail)?;

        for ended in endings {
            prop_assert_eq!(ended, Ok(Value::Null));
        }
        for joined in &joined_pairings {
            let join_state = read_join_state(&joined.joiner).map_err(fail)?;
            prop_assert_eq!(join_state, ending.expected_join_state());
        }
        prop_assert_eq!(status_problem, Value::Null);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DESK_CASES))]

    #[test]
    fn test_withdraw_when_published_property_a_failing_read_withdraws_quietly(
        reads_before_restart in 0..=MOST_READS_BEFORE_RESTART,
    ) {
        let mut desk = ApproverDesk::open().map_err(fail)?;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        for _ in 0..reads_before_restart {
            read_request(&desk.approver, &code).map_err(fail)?;
        }

        desk.approver.restart().map_err(fail)?;
        let read_after_restart = read_request(&desk.approver, &code);
        let status_problem =
            read_status_problem(&desk.approver).map_err(fail)?;

        prop_assert_eq!(read_after_restart, Err(NOT_STARTED_HERE.to_owned()));
        prop_assert_eq!(status_problem, Value::Null);
    }

    #[test]
    fn test_withdraw_announced_code_property_no_board_is_needed_to_end(
        peer_relay in crossing_relay_choices(),
        ending in pairing_endings(),
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_request(&desk.approver, &code).map_err(fail)?;

        let ended = desk.end(&desk.approver, ending, &code);
        let status_problem =
            read_status_problem(&desk.approver).map_err(fail)?;
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        let reply_problem = &joined.session["rendezvous_problem"];
        prop_assert_eq!(reply_problem, &json!(NO_PEER_ENDPOINT));
        prop_assert_eq!(ended, Ok(Value::Null));
        prop_assert_eq!(status_problem, Value::Null);
        prop_assert_eq!(join_state, ending.expected_join_state());
    }
}

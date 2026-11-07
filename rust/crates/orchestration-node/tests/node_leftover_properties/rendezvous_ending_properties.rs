use std::sync::Mutex;
use std::thread;
use std::time::Duration;

use orchestration_node::node_configuration::PeerRelayChoice;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::approver_desk::{
    ApproverDesk, DESK_CASES, PairingEnding, pairing_endings, read_request,
    read_status_problem, start_pairing,
};
use crate::at_once::run_at_once;
use crate::command_device::{BareNode, CommandDevice, crossing_relay_choices};
use crate::short_session_server::{
    SHORT_SESSION_LIFETIME, SessionLifetime, ShortSessionServer,
};
use crate::support::test_device::fail;

const NO_PEER_ENDPOINT: &str = "this node has no peer endpoint";
const EXPIRY_MARGIN: Duration = Duration::from_millis(400);
const MOST_CODES: usize = 3;

fn open_short_desk(
    peer_relay: PeerRelayChoice,
) -> Result<(ShortSessionServer, BareNode), String> {
    let server = ShortSessionServer::start()?;
    let approver = BareNode::open(peer_relay)?;
    approver.run(&server.build_create_account_command()?)?;
    Ok((server, approver))
}

fn cancel(
    device: &dyn CommandDevice,
    session: &Value,
) -> Result<Value, String> {
    let code = &session["code"];
    device.run(&json!({ "command": "cancel_pairing", "code": code }))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DESK_CASES))]

    #[test]
    fn test_forget_problem_of_property_ending_older_codes_keeps_it(
        peer_relay in crossing_relay_choices(),
        older_count in 1..MOST_CODES,
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let mut older_sessions = Vec::new();
        for _ in 0..older_count {
            older_sessions.push(start_pairing(&desk.approver).map_err(fail)?);
        }
        start_pairing(&desk.approver).map_err(fail)?;

        for older_session in older_sessions.iter().rev() {
            cancel(&desk.approver, older_session).map_err(fail)?;
            let problem = read_status_problem(&desk.approver).map_err(fail)?;
            prop_assert_eq!(problem, json!(NO_PEER_ENDPOINT));
        }
    }

    #[test]
    fn test_forget_problem_of_property_a_later_failure_shows_again(
        peer_relay in crossing_relay_choices(),
        round_count in 1..MOST_CODES,
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;

        for _ in 0..round_count {
            let session = start_pairing(&desk.approver).map_err(fail)?;
            let shown = read_status_problem(&desk.approver).map_err(fail)?;
            cancel(&desk.approver, &session).map_err(fail)?;
            let cleared = read_status_problem(&desk.approver).map_err(fail)?;

            prop_assert_eq!(shown, json!(NO_PEER_ENDPOINT));
            prop_assert_eq!(cleared, Value::Null);
        }
    }

    #[test]
    fn test_forget_problem_of_property_a_second_ending_keeps_it_clear(
        peer_relay in crossing_relay_choices(),
        second_ending in pairing_endings(),
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let session = start_pairing(&desk.approver).map_err(fail)?;
        cancel(&desk.approver, &session).map_err(fail)?;

        let ended_again =
            desk.end(&desk.approver, second_ending, &session["code"]);
        let problem = read_status_problem(&desk.approver).map_err(fail)?;

        prop_assert!(ended_again.is_err(), "{:?}", ended_again);
        prop_assert_eq!(problem, Value::Null);
    }

    #[test]
    fn test_end_announcement_property_a_local_device_never_shows_one(
        ending in pairing_endings(),
        read_count in 0_usize..2,
    ) {
        let desk = ApproverDesk::open_bare(PeerRelayChoice::Disabled)
            .map_err(fail)?;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        for _ in 0..read_count {
            read_request(&desk.approver, &code).map_err(fail)?;
        }

        desk.end(&desk.approver, ending, &code).map_err(fail)?;
        let problem = read_status_problem(&desk.approver).map_err(fail)?;

        prop_assert_eq!(&joined.session["rendezvous_problem"], &Value::Null);
        prop_assert_eq!(problem, Value::Null);
    }

    #[test]
    fn test_end_announcement_property_codes_ended_at_once_clear_it(
        peer_relay in crossing_relay_choices(),
        code_count in 2..=MOST_CODES,
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
        let problem = read_status_problem(&desk.approver).map_err(fail)?;

        for cancel_outcome in cancelled {
            prop_assert_eq!(cancel_outcome, Ok(Value::Null));
        }
        prop_assert_eq!(problem, Value::Null);
    }

    #[test]
    fn test_end_announcement_property_a_read_then_answer_stays_clear(
        peer_relay in crossing_relay_choices(),
        ending in pairing_endings(),
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_request(&desk.approver, &code).map_err(fail)?;

        desk.end(&desk.approver, ending, &code).map_err(fail)?;
        let after_ending = read_status_problem(&desk.approver).map_err(fail)?;
        start_pairing(&desk.approver).map_err(fail)?;
        let after_start = read_status_problem(&desk.approver).map_err(fail)?;

        prop_assert_eq!(after_ending, Value::Null);
        prop_assert_eq!(after_start, json!(NO_PEER_ENDPOINT));
    }

    #[test]
    fn test_schedule_expiry_property_an_ended_code_expires_quietly(
        peer_relay in crossing_relay_choices(),
    ) {
        let (server, approver) = open_short_desk(peer_relay).map_err(fail)?;
        server
            .start_pairing_lasting(&approver, SessionLifetime::Short)
            .map_err(fail)?;
        let live_session = start_pairing(&approver).map_err(fail)?;
        cancel(&approver, &live_session).map_err(fail)?;

        let before_expiry = read_status_problem(&approver).map_err(fail)?;
        thread::sleep(SHORT_SESSION_LIFETIME + EXPIRY_MARGIN);
        let after_expiry = read_status_problem(&approver).map_err(fail)?;

        prop_assert_eq!(before_expiry, Value::Null);
        prop_assert_eq!(after_expiry, Value::Null);
    }

    #[test]
    fn test_schedule_expiry_property_a_failure_after_expiry_shows_again(
        peer_relay in crossing_relay_choices(),
    ) {
        let (server, approver) = open_short_desk(peer_relay).map_err(fail)?;
        server
            .start_pairing_lasting(&approver, SessionLifetime::Short)
            .map_err(fail)?;
        thread::sleep(SHORT_SESSION_LIFETIME + EXPIRY_MARGIN);
        let after_expiry = read_status_problem(&approver).map_err(fail)?;

        let session = start_pairing(&approver).map_err(fail)?;
        let after_start = read_status_problem(&approver).map_err(fail)?;

        prop_assert_eq!(after_expiry, Value::Null);
        let reply_problem = &session["rendezvous_problem"];
        prop_assert_eq!(reply_problem, &json!(NO_PEER_ENDPOINT));
        prop_assert_eq!(after_start, json!(NO_PEER_ENDPOINT));
    }
}

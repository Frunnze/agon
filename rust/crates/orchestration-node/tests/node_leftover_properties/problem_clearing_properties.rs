use std::thread;
use std::time::Duration;

use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};

use crate::approver_desk::{
    ApproverDesk, DESK_CASES, PairingEnding, pairing_endings,
    read_approver_words, read_joiner_words, read_status_problem,
    start_pairing,
};
use crate::command_device::{BareNode, CommandDevice, crossing_relay_choices};
use crate::meddling_server::EndingAnswer;
use crate::short_session_server::{
    SESSION_LIFETIMES, SHORT_SESSION_LIFETIME, SessionLifetime,
    ShortSessionServer,
};
use crate::support::test_device::fail;

const NO_PEER_ENDPOINT: &str = "this node has no peer endpoint";
const EXPIRY_MARGIN: Duration = Duration::from_millis(400);

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DESK_CASES))]

    #[test]
    fn test_withdraw_announced_code_property_ending_its_code_clears_it(
        peer_relay in crossing_relay_choices(),
        ending in pairing_endings(),
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        let problem_before =
            read_status_problem(&desk.approver).map_err(fail)?;

        desk.end(&desk.approver, ending, &code).map_err(fail)?;
        let problem_after =
            read_status_problem(&desk.approver).map_err(fail)?;

        prop_assert_eq!(problem_before, json!(NO_PEER_ENDPOINT));
        prop_assert_eq!(problem_after, Value::Null);
    }

    #[test]
    fn test_withdraw_announced_code_property_an_older_code_keeps_the_newest(
        peer_relay in crossing_relay_choices(),
        ending in pairing_endings(),
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let older = desk.start_and_join().map_err(fail)?;
        let newer = desk.start_and_join().map_err(fail)?;

        desk.end(&desk.approver, ending, &older.session["code"])
            .map_err(fail)?;
        let problem_after_older =
            read_status_problem(&desk.approver).map_err(fail)?;
        desk.end(&desk.approver, ending, &newer.session["code"])
            .map_err(fail)?;
        let problem_after_newer =
            read_status_problem(&desk.approver).map_err(fail)?;

        prop_assert_eq!(problem_after_older, json!(NO_PEER_ENDPOINT));
        prop_assert_eq!(problem_after_newer, Value::Null);
    }

    #[test]
    fn test_withdraw_announced_code_property_showing_the_joiner_clears_it(
        peer_relay in crossing_relay_choices(),
        read_count in 1_usize..3,
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();

        for _ in 0..read_count {
            let approver_words =
                read_approver_words(&desk.approver, &code).map_err(fail)?;
            let joiner_words =
                read_joiner_words(&joined.joiner).map_err(fail)?;
            let problem =
                read_status_problem(&desk.approver).map_err(fail)?;

            prop_assert_eq!(approver_words, joiner_words);
            prop_assert_eq!(problem, Value::Null);
        }
    }

    #[test]
    fn test_end_pairing_here_property_a_refused_cancel_clears_the_problem(
        peer_relay in crossing_relay_choices(),
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let session = start_pairing(&desk.approver).map_err(fail)?;

        desk.server.answer_endings(EndingAnswer::Refused);
        let cancelled =
            desk.end(&desk.approver, PairingEnding::Cancel, &session["code"]);
        desk.reset_meddling();
        let problem = read_status_problem(&desk.approver).map_err(fail)?;

        let reply_problem = &session["rendezvous_problem"];
        prop_assert_eq!(reply_problem, &json!(NO_PEER_ENDPOINT));
        prop_assert!(cancelled.is_err(), "{:?}", cancelled);
        prop_assert_eq!(problem, Value::Null);
    }

    #[test]
    fn test_schedule_expiry_property_an_expired_newest_code_clears_it(
        peer_relay in crossing_relay_choices(),
        newest_lifetime in select(SESSION_LIFETIMES.to_vec()),
    ) {
        let server = ShortSessionServer::start().map_err(fail)?;
        let approver = BareNode::open(peer_relay).map_err(fail)?;
        let account_command =
            server.build_create_account_command().map_err(fail)?;
        approver.run(&account_command).map_err(fail)?;

        let older_lifetime = if newest_lifetime == SessionLifetime::Short {
            SessionLifetime::Normal
        } else {
            SessionLifetime::Short
        };
        let older = server
            .start_pairing_lasting(&approver, older_lifetime)
            .map_err(fail)?;
        let newer = server
            .start_pairing_lasting(&approver, newest_lifetime)
            .map_err(fail)?;
        thread::sleep(SHORT_SESSION_LIFETIME + EXPIRY_MARGIN);
        let problem = read_status_problem(&approver).map_err(fail)?;

        let failed_publish = json!(NO_PEER_ENDPOINT);
        prop_assert_eq!(&older["rendezvous_problem"], &failed_publish);
        prop_assert_eq!(&newer["rendezvous_problem"], &failed_publish);
        if newest_lifetime == SessionLifetime::Short {
            prop_assert_eq!(problem, Value::Null);
        } else {
            prop_assert_eq!(problem, json!(NO_PEER_ENDPOINT));
        }
    }
}

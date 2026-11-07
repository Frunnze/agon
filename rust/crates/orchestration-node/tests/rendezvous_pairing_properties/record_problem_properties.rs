use std::collections::BTreeSet;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::approver_desk::{
    APPROVED_STATE, ApproverDesk, DESK_CASES, read_approver_words,
    read_join_state, read_joiner_words, read_status_problem,
};
use crate::command_device::crossing_relay_choices;
use crate::pairing_actions::{
    NO_PEER_ENDPOINT, PairingAction, observe_pairing_actions, pairing_actions,
};
use crate::support::test_device::fail;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DESK_CASES))]

    #[test]
    fn test_record_problem_property_the_status_names_the_newest_failure(
        peer_relay in crossing_relay_choices(),
        actions in pairing_actions(),
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;

        let observations =
            observe_pairing_actions(&desk, &actions).map_err(fail)?;

        for observation in &observations {
            if let Some(session) = &observation.started_session {
                let reply_problem = &session["rendezvous_problem"];
                prop_assert_eq!(reply_problem, &json!(NO_PEER_ENDPOINT));
                prop_assert_eq!(&observation.status_problem, reply_problem);
            }
        }
    }

    #[test]
    fn test_record_problem_property_a_failed_publish_never_blocks_pairing(
        peer_relay in crossing_relay_choices(),
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();

        let approver_words =
            read_approver_words(&desk.approver, &code).map_err(fail)?;
        let joiner_words = read_joiner_words(&joined.joiner).map_err(fail)?;
        let approved = desk.approve(&desk.approver, &code);
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        prop_assert_eq!(
            &joined.session["rendezvous_problem"],
            &json!(NO_PEER_ENDPOINT)
        );
        prop_assert_eq!(approver_words, joiner_words);
        prop_assert_eq!(approved, Ok(Value::Null));
        prop_assert_eq!(join_state, json!(APPROVED_STATE));
    }

    #[test]
    fn test_record_problem_property_every_shown_problem_was_a_failure(
        peer_relay in crossing_relay_choices(),
        actions in pairing_actions(),
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let status_before = read_status_problem(&desk.approver)
            .map_err(fail)?;

        let observations =
            observe_pairing_actions(&desk, &actions).map_err(fail)?;

        let mut failures_seen = BTreeSet::new();
        let mut is_newest_failure_live = false;
        for (action, observation) in actions.iter().zip(&observations) {
            if let Some(session) = &observation.started_session {
                let reply_problem = &session["rendezvous_problem"];
                failures_seen.insert(reply_problem.to_string());
                is_newest_failure_live = !reply_problem.is_null();
            }
            if matches!(action, PairingAction::CancelLatest) {
                is_newest_failure_live = false;
            }
            let shown = &observation.status_problem;
            prop_assert_eq!(
                !shown.is_null(),
                is_newest_failure_live,
                "{:?}",
                observation
            );
            if !shown.is_null() {
                let is_seen = failures_seen.contains(&shown.to_string());
                prop_assert!(is_seen, "{:?}", observation);
            }
        }
        prop_assert_eq!(status_before, Value::Null);
    }
}

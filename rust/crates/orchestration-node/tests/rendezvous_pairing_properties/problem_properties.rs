use orchestration_node::node_configuration::PeerRelayChoice;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::approver_desk::{
    ApproverDesk, DESK_CASES, read_status_problem, start_pairing,
};
use crate::command_device::{BareNode, every_relay_choice};
use crate::pairing_actions::{
    NO_PEER_ENDPOINT, observe_pairing_actions, pairing_actions,
};
use crate::support::test_device::fail;

fn expected_publish_problem(peer_relay: &PeerRelayChoice) -> Value {
    if *peer_relay == PeerRelayChoice::Disabled {
        return Value::Null;
    }
    json!(NO_PEER_ENDPOINT)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DESK_CASES))]

    #[test]
    fn test_problem_property_a_fresh_device_names_no_problem(
        peer_relay in every_relay_choice(),
    ) {
        let node = BareNode::open(peer_relay).map_err(fail)?;
        let problem_without_account =
            read_status_problem(&node).map_err(fail)?;
        let desk = ApproverDesk::open_with(node).map_err(fail)?;
        let problem_with_account =
            read_status_problem(&desk.approver).map_err(fail)?;

        prop_assert_eq!(problem_without_account, Value::Null);
        prop_assert_eq!(problem_with_account, Value::Null);
    }

    #[test]
    fn test_problem_property_reading_the_status_changes_nothing(
        peer_relay in every_relay_choice(),
        actions in pairing_actions(),
    ) {
        let expected_problem = expected_publish_problem(&peer_relay);
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        observe_pairing_actions(&desk, &actions).map_err(fail)?;

        let first_read = read_status_problem(&desk.approver).map_err(fail)?;
        let second_read = read_status_problem(&desk.approver).map_err(fail)?;
        let session = start_pairing(&desk.approver).map_err(fail)?;
        let read_after_start =
            read_status_problem(&desk.approver).map_err(fail)?;

        prop_assert_eq!(first_read, second_read);
        prop_assert_eq!(&session["rendezvous_problem"], &expected_problem);
        prop_assert_eq!(read_after_start, expected_problem);
    }

    #[test]
    fn test_problem_property_a_local_only_device_never_names_a_problem(
        actions in pairing_actions(),
    ) {
        let desk = ApproverDesk::open().map_err(fail)?;

        let observations =
            observe_pairing_actions(&desk, &actions).map_err(fail)?;

        for observation in &observations {
            if let Some(session) = &observation.started_session {
                prop_assert_eq!(&session["rendezvous_problem"], &Value::Null);
            }
            prop_assert_eq!(&observation.status_problem, &Value::Null);
        }
    }
}

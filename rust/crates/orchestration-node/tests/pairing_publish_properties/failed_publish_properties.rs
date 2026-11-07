use orchestration_node::node_configuration::PeerRelayChoice;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::pairing_desk::{
    BareDevice, LocalAppServer, NO_PEER_ENDPOINT, PUBLISH_CASES,
    PairingAction, cancel_pairing, fail, pairing_actions, peer_relay_choices,
    read_reply_problem, start_pairing,
};
use crate::pairing_sequences::observe_pairing_actions;

const LARGEST_START_COUNT: usize = 3;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PUBLISH_CASES))]

    #[test]
    fn test_start_pairing_property_a_failed_publish_is_named_in_the_reply(
        actions in pairing_actions(),
    ) {
        let server = LocalAppServer::start().map_err(fail)?;
        let device =
            BareDevice::open_with_account(&server, PeerRelayChoice::Default)
                .map_err(fail)?;

        let observations =
            observe_pairing_actions(&device, &actions).map_err(fail)?;

        for observation in &observations {
            if let Some(session) = &observation.started_session {
                prop_assert_eq!(
                    read_reply_problem(session),
                    Ok(json!(NO_PEER_ENDPOINT))
                );
            }
        }
    }

    #[test]
    fn test_announce_code_property_a_failed_publish_shows_in_the_status(
        actions in pairing_actions(),
    ) {
        let server = LocalAppServer::start().map_err(fail)?;
        let device =
            BareDevice::open_with_account(&server, PeerRelayChoice::Default)
                .map_err(fail)?;

        let observations =
            observe_pairing_actions(&device, &actions).map_err(fail)?;

        for observation in &observations {
            if matches!(observation.action, PairingAction::Start) {
                prop_assert_eq!(
                    &observation.status_problem_after,
                    &json!(NO_PEER_ENDPOINT)
                );
            }
        }
    }

    #[test]
    fn test_start_pairing_property_the_reply_agrees_with_the_status_after_it(
        peer_relay in peer_relay_choices(),
        actions in pairing_actions(),
    ) {
        let server = LocalAppServer::start().map_err(fail)?;
        let device = BareDevice::open_with_account(&server, peer_relay)
            .map_err(fail)?;

        let observations =
            observe_pairing_actions(&device, &actions).map_err(fail)?;

        for observation in &observations {
            if let Some(session) = &observation.started_session {
                prop_assert_eq!(
                    read_reply_problem(session),
                    Ok(observation.status_problem_after.clone())
                );
            }
        }
    }

    #[test]
    fn test_withdraw_announced_code_property_cancelling_clears_its_problem(
        peer_relay in peer_relay_choices(),
        actions in pairing_actions(),
    ) {
        let server = LocalAppServer::start().map_err(fail)?;
        let device = BareDevice::open_with_account(&server, peer_relay)
            .map_err(fail)?;

        let observations =
            observe_pairing_actions(&device, &actions).map_err(fail)?;

        let mut is_code_showing = false;
        for observation in &observations {
            if observation.started_session.is_some() {
                is_code_showing = true;
            }
            if !matches!(observation.action, PairingAction::CancelLatest) {
                continue;
            }
            if is_code_showing {
                prop_assert_eq!(
                    &observation.status_problem_after,
                    &Value::Null,
                    "{:?}",
                    observation
                );
            } else {
                prop_assert_eq!(
                    &observation.status_problem_after,
                    &observation.status_problem_before,
                    "{:?}",
                    observation
                );
            }
            is_code_showing = false;
        }
    }

    #[test]
    fn test_withdraw_announced_code_property_cancelling_unpublished_succeeds(
        peer_relay in peer_relay_choices(),
        start_count in 1..=LARGEST_START_COUNT,
    ) {
        let server = LocalAppServer::start().map_err(fail)?;
        let device = BareDevice::open_with_account(&server, peer_relay)
            .map_err(fail)?;

        for _ in 0..start_count {
            let session = start_pairing(&device).map_err(fail)?;
            let cancelled = cancel_pairing(&device, &session);

            prop_assert_eq!(cancelled, Ok(Value::Null));
        }
    }
}

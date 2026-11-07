use orchestration_node::node_configuration::PeerRelayChoice;
use proptest::prelude::*;
use serde_json::Value;

use crate::pairing_desk::{
    BareDevice, LocalAppServer, PUBLISH_CASES, RuntimeDevice, cancel_pairing,
    fail, pairing_actions, read_reply_problem, read_status_problem,
    start_pairing,
};
use crate::pairing_sequences::observe_pairing_actions;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PUBLISH_CASES))]

    #[test]
    fn test_announce_code_property_a_local_only_reply_names_no_problem(
        actions in pairing_actions(),
    ) {
        let server = LocalAppServer::start().map_err(fail)?;
        let device =
            BareDevice::open_with_account(&server, PeerRelayChoice::Disabled)
                .map_err(fail)?;

        let observations =
            observe_pairing_actions(&device, &actions).map_err(fail)?;

        for observation in &observations {
            if let Some(session) = &observation.started_session {
                prop_assert_eq!(read_reply_problem(session), Ok(Value::Null));
            }
        }
    }

    #[test]
    fn test_withdraw_announced_code_property_local_only_records_no_problem(
        actions in pairing_actions(),
    ) {
        let server = LocalAppServer::start().map_err(fail)?;
        let device =
            BareDevice::open_with_account(&server, PeerRelayChoice::Disabled)
                .map_err(fail)?;

        let observations =
            observe_pairing_actions(&device, &actions).map_err(fail)?;

        for observation in &observations {
            prop_assert_eq!(
                &observation.status_problem_after,
                &Value::Null,
                "{:?}",
                observation
            );
        }
    }

    #[test]
    fn test_announce_code_property_a_new_code_never_shows_an_old_reason(
        actions in pairing_actions(),
    ) {
        let server = LocalAppServer::start().map_err(fail)?;
        let device =
            BareDevice::open_with_account(&server, PeerRelayChoice::Disabled)
                .map_err(fail)?;
        let first_session = start_pairing(&device).map_err(fail)?;
        cancel_pairing(&device, &first_session).map_err(fail)?;
        observe_pairing_actions(&device, &actions).map_err(fail)?;

        let newest_session = start_pairing(&device).map_err(fail)?;
        let status_problem = read_status_problem(&device);

        prop_assert_eq!(read_reply_problem(&newest_session), Ok(Value::Null));
        prop_assert_eq!(status_problem, Ok(Value::Null));
    }

    #[test]
    fn test_start_pairing_property_a_local_network_device_reports_no_problem(
        actions in pairing_actions(),
    ) {
        let server = LocalAppServer::start().map_err(fail)?;
        let device =
            RuntimeDevice::start_local_only_with_account(&server)
                .map_err(fail)?;

        let observations =
            observe_pairing_actions(&device, &actions).map_err(fail)?;

        for observation in &observations {
            if let Some(session) = &observation.started_session {
                prop_assert_eq!(read_reply_problem(session), Ok(Value::Null));
            }
            prop_assert_eq!(&observation.status_problem_after, &Value::Null);
        }
    }
}

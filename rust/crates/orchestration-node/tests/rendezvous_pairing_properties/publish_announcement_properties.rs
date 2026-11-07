use chrono::{DateTime, Utc};
use orchestration_node::node_configuration::PeerRelayChoice;
use orchestration_security::pairing::PairingCode;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::approver_desk::{
    ApproverDesk, DESK_CASES, read_status_problem, start_pairing,
};
use crate::command_device::{CommandDevice, crossing_relay_choices};
use crate::pairing_actions::NO_PEER_ENDPOINT;
use crate::support::test_device::{fail, read_text};

const MOST_STARTS: usize = 3;
const LOOPBACK_RELAY_PREFIX: &str = "http://127.0.0.1:";

fn read_time(
    session: &Value,
    field_name: &str,
) -> Result<DateTime<Utc>, String> {
    serde_json::from_value(session[field_name].clone())
        .map_err(|problem| problem.to_string())
}

fn collect_started_problems<Approver: CommandDevice>(
    desk: &ApproverDesk<Approver>,
    start_count: usize,
) -> Result<Vec<(Value, Value)>, String> {
    let mut started_problems = Vec::new();
    for _ in 0..start_count {
        let session = start_pairing(&desk.approver)?;
        let status_problem = read_status_problem(&desk.approver)?;
        started_problems
            .push((session["rendezvous_problem"].clone(), status_problem));
    }
    Ok(started_problems)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DESK_CASES))]

    #[test]
    fn test_publish_announcement_property_a_failed_publish_keeps_the_session(
        peer_relay in crossing_relay_choices(),
        start_count in 1..=MOST_STARTS,
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;

        for _ in 0..start_count {
            let session = start_pairing(&desk.approver).map_err(fail)?;
            let code = read_text(&session, "/code").map_err(fail)?;
            let display_code =
                read_text(&session, "/display_code").map_err(fail)?;
            let parsed_code = PairingCode::parse(&code).map_err(fail)?;
            let started_at = read_time(&session, "started_at").map_err(fail)?;
            let expires_at = read_time(&session, "expires_at").map_err(fail)?;

            prop_assert_eq!(String::from(parsed_code.clone()), code);
            prop_assert_eq!(display_code, parsed_code.display());
            prop_assert!(started_at < expires_at);
            prop_assert_eq!(
                &session["rendezvous_problem"],
                &json!(NO_PEER_ENDPOINT)
            );
        }
    }

    #[test]
    fn test_publish_announcement_property_a_local_only_node_never_publishes(
        has_peer_side in any::<bool>(),
        start_count in 1..=MOST_STARTS,
    ) {
        let started_problems = if has_peer_side {
            let desk = ApproverDesk::open().map_err(fail)?;
            collect_started_problems(&desk, start_count)
        } else {
            let desk = ApproverDesk::open_bare(PeerRelayChoice::Disabled)
                .map_err(fail)?;
            collect_started_problems(&desk, start_count)
        };

        let started_problems = started_problems.map_err(fail)?;
        for (reply_problem, status_problem) in started_problems {
            prop_assert_eq!(reply_problem, Value::Null);
            prop_assert_eq!(status_problem, Value::Null);
        }
    }

    #[test]
    fn test_publish_announcement_property_every_relay_address_crosses(
        relay_port in 1..=u16::MAX,
    ) {
        let relay_address = format!("{LOOPBACK_RELAY_PREFIX}{relay_port}");
        let peer_relay = PeerRelayChoice::Custom(relay_address);
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;

        let session = start_pairing(&desk.approver).map_err(fail)?;
        let status_problem =
            read_status_problem(&desk.approver).map_err(fail)?;

        prop_assert_eq!(
            &session["rendezvous_problem"],
            &json!(NO_PEER_ENDPOINT)
        );
        prop_assert_eq!(status_problem, json!(NO_PEER_ENDPOINT));
    }
}

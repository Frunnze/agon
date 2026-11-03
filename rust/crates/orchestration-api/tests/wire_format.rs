#![allow(clippy::expect_used)]

use orchestration_api::accounts::{
    JoinRequest, JoinStatus, PublishPeerAddressRequest,
};
use orchestration_api::updates::{
    ChangeNotification, ChangeTopic, EventsResponse,
};
use orchestration_api::work::{RunEvent, RunEventsRequest, TaskStart};
use orchestration_core::device::{DeviceRole, HardwareKeyKind};
use orchestration_core::identifiers::RunId;
use orchestration_core::peer_address::{PeerAddress, SignedPeerAddress};
use proptest::prelude::*;
use serde::Serialize;
use serde::de::DeserializeOwned;
use uuid::Uuid;

fn round_trip<Value>(value: &Value) -> Value
where
    Value: Serialize + DeserializeOwned,
{
    let encoded_value =
        serde_json::to_string(value).expect("value encodes as JSON");
    serde_json::from_str(&encoded_value).expect("value decodes from JSON")
}

fn join_request_for(code: String, name: String) -> JoinRequest {
    JoinRequest {
        code,
        device: orchestration_api::accounts::DeviceRegistration {
            name,
            role: DeviceRole::Runner,
            key_kind: HardwareKeyKind::Software,
            signing_public_key: vec![1, 2, 3],
            sealing_public_key: vec![4, 5, 6],
        },
    }
}

#[test]
fn join_status_uses_a_state_tag() {
    let waiting = JoinStatus::Waiting {
        approver_nonce: Some(vec![7]),
    };

    let encoded_status =
        serde_json::to_string(&waiting).expect("status encodes as JSON");

    assert_eq!(
        encoded_status,
        r#"{"state":"waiting","approver_nonce":[7]}"#
    );
}

#[test]
fn task_start_is_written_in_snake_case() {
    let encoded_start = serde_json::to_string(&TaskStart::Later)
        .expect("start encodes as JSON");

    assert_eq!(encoded_start, r#""later""#);
}

#[test]
fn run_events_keep_their_order_through_json() {
    let events_request = RunEventsRequest {
        events: vec![
            RunEvent::WorktreeCreated {
                branch: "task/ship-release-2-4".to_owned(),
            },
            RunEvent::SessionStarted {
                session: "7c1e".to_owned(),
            },
            RunEvent::Finished,
        ],
    };

    assert_eq!(round_trip(&events_request), events_request);
}

#[test]
fn a_step_result_event_uses_its_own_kind_tag() {
    let event = RunEvent::StepResultRecorded {
        step_name: "plan".to_owned(),
        result: "sealed:abc".to_owned(),
        outcome: None,
    };

    let encoded_event =
        serde_json::to_value(&event).expect("event encodes as JSON");

    assert_eq!(encoded_event["kind"], "step_result_recorded");
    assert_eq!(encoded_event["step_name"], "plan");
}

proptest! {
    #[test]
    fn test_run_event_property_step_results_survive_json_round_trip(
        step_name in "\\PC{0,30}",
        result in "\\PC{0,200}",
        outcome in proptest::option::of("[a-z][a-z0-9 -]{0,20}"),
    ) {
        let event = RunEvent::StepResultRecorded {
            step_name,
            result,
            outcome,
        };

        prop_assert_eq!(round_trip(&event), event);
    }

    #[test]
    fn test_join_request_property_survives_json_round_trip(
        code in "[A-Z0-9]{6}",
        name in "\\PC{0,40}",
    ) {
        let join_request = join_request_for(code, name);

        prop_assert_eq!(round_trip(&join_request), join_request);
    }

    #[test]
    fn test_events_response_property_keeps_every_notification(
        sequences in proptest::collection::vec(any::<u64>(), 0..20),
        run_bits in any::<u128>(),
    ) {
        let run_id = RunId(Uuid::from_u128(run_bits));
        let notifications: Vec<ChangeNotification> = sequences
            .iter()
            .map(|sequence| ChangeNotification {
                sequence: *sequence,
                topic: ChangeTopic::Run { run_id },
            })
            .collect();
        let latest_sequence =
            sequences.iter().copied().max().unwrap_or_default();
        let events_response = EventsResponse {
            notifications,
            latest_sequence,
        };

        prop_assert_eq!(round_trip(&events_response), events_response);
    }

    #[test]
    fn test_run_event_property_rejects_arbitrary_text_without_panic(
        arbitrary_text in "\\PC{0,200}",
    ) {
        let decoded_event: Result<RunEvent, _> =
            serde_json::from_str(&arbitrary_text);

        prop_assert!(decoded_event.is_ok() || decoded_event.is_err());
    }
}

proptest! {
    #[test]
    fn test_publish_peer_address_request_property_survives_json(
        key in any::<[u8; 32]>(),
        port in any::<u16>(),
        relay_url in proptest::option::of("https://[a-z]{1,8}\\.example/"),
        signature in proptest::collection::vec(any::<u8>(), 0..64),
    ) {
        let address = PeerAddress {
            endpoint_public_key: key,
            direct_addresses: vec![std::net::SocketAddr::from(
                ([127, 0, 0, 1], port),
            )],
            relay_url,
        };
        let request = PublishPeerAddressRequest {
            address: SignedPeerAddress {
                device_id: orchestration_core::identifiers::DeviceId(
                    "device".to_owned(),
                ),
                address,
                published_at: chrono::DateTime::UNIX_EPOCH,
                signature,
            },
        };

        prop_assert_eq!(round_trip(&request), request);
    }
}

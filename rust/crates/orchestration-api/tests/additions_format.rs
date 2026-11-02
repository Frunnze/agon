#![allow(clippy::expect_used)]

use orchestration_api::accounts::revocation_statement;
use orchestration_api::server_group::ReplicaQuery;
use orchestration_api::updates::{ChangeTopic, EventsQuery};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::ServerStanding;
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_revocation_statement_property_differs_for_different_devices(
        first_text in "[0-9a-f]{32}",
        second_text in "[0-9a-f]{32}",
    ) {
        prop_assume!(first_text != second_text);
        let first_statement =
            revocation_statement(&DeviceId(first_text));
        let second_statement =
            revocation_statement(&DeviceId(second_text));

        prop_assert_ne!(first_statement, second_statement);
    }

    #[test]
    fn test_revocation_statement_property_ends_with_the_device_id(
        device_text in "\\PC{0,40}",
    ) {
        let statement =
            revocation_statement(&DeviceId(device_text.clone()));

        prop_assert!(statement.ends_with(device_text.as_bytes()));
    }

    #[test]
    fn test_events_query_property_survives_json_round_trip(
        after in any::<u64>(),
    ) {
        let query = EventsQuery { after };
        let encoded_query = serde_json::to_string(&query)
            .expect("query encodes as JSON");
        let decoded_query: EventsQuery = serde_json::from_str(&encoded_query)
            .expect("query decodes from JSON");

        prop_assert_eq!(decoded_query, query);
    }
}

proptest! {
    #[test]
    fn test_replica_query_property_survives_json_round_trip(
        after in any::<u64>(),
    ) {
        let query = ReplicaQuery { after };
        let encoded_query = serde_json::to_string(&query)
            .expect("query encodes as JSON");
        let decoded_query: ReplicaQuery = serde_json::from_str(&encoded_query)
            .expect("query decodes from JSON");

        prop_assert_eq!(decoded_query, query);
    }
}

#[test]
fn test_change_topic_property_names_the_server_group_topic() {
    let encoded = serde_json::to_string(&ChangeTopic::ServerGroup)
        .expect("the topic encodes as JSON");

    assert_eq!(encoded, r#"{"topic":"server_group"}"#);
}

#[test]
fn test_server_standing_property_uses_lowercase_words() {
    let encoded = serde_json::to_string(&[
        ServerStanding::Active,
        ServerStanding::Backup,
    ])
    .expect("the standings encode as JSON");

    assert_eq!(encoded, r#"["active","backup"]"#);
}

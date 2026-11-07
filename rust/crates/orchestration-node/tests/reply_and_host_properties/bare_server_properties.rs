use orchestration_core::peer_address::PeerAddress;
use orchestration_node::code_rendezvous::decode_rendezvous_record;
use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;

use crate::rendezvous_records::{
    DIRECT_PREFIX, SERVER_PREFIX, crowded_peer_strategy, decode_problem,
    describe_malformed_field, fields_named, live_record_strategy,
};
use crate::support::test_device::fail;

const SERVER_TEXT_PATTERN: &str = "\\PC{0,30}";

fn replace_server_field(fields: &[String], server_field: &str) -> Vec<String> {
    let mut replaced_fields = Vec::new();
    for field in fields {
        if field.starts_with(SERVER_PREFIX) {
            replaced_fields.push(server_field.to_owned());
        } else {
            replaced_fields.push(field.clone());
        }
    }
    replaced_fields
}

fn has_direct_addresses(peer_address: &PeerAddress) -> bool {
    !peer_address.direct_addresses.is_empty()
}

fn is_unparsable_server(server_text: &str) -> bool {
    ServerAddress::parse(server_text).is_err()
}

fn addressed_peer_strategy() -> impl Strategy<Value = PeerAddress> {
    crowded_peer_strategy().prop_filter("addressed", has_direct_addresses)
}

fn unparsable_server_strategy() -> impl Strategy<Value = String> {
    SERVER_TEXT_PATTERN
        .prop_filter("unparsable", |text| is_unparsable_server(text))
}

proptest! {
    #[test]
    fn test_parse_bare_server_property_refuses_direct_addresses(
        record in live_record_strategy(),
        peer_address in addressed_peer_strategy(),
    ) {
        let addressed_server = ServerAddress::Peer(peer_address);
        let server_field = format!("{SERVER_PREFIX}{addressed_server}");
        let fields = replace_server_field(&record.fields, &server_field);

        let problem = decode_problem(&fields, record.now);

        let expected = describe_malformed_field(&server_field);
        prop_assert_eq!(problem, Some(expected));
    }

    #[test]
    fn test_parse_bare_server_property_adds_no_addresses_of_its_own(
        record in live_record_strategy(),
    ) {
        prop_assume!(matches!(record.server, ServerAddress::Peer(_)));

        let decoded = decode_rendezvous_record(&record.fields, record.now)
            .map_err(fail)?;

        let direct_values = fields_named(&record.fields, DIRECT_PREFIX);
        let mut decoded_values = Vec::new();
        for direct_address in decoded.direct_addresses() {
            decoded_values.push(direct_address.to_string());
        }
        prop_assert_eq!(decoded_values, direct_values);
    }

    #[test]
    fn test_parse_bare_server_property_refuses_what_parsing_refuses(
        record in live_record_strategy(),
        server_text in unparsable_server_strategy(),
    ) {
        let server_field = format!("{SERVER_PREFIX}{server_text}");
        let fields = replace_server_field(&record.fields, &server_field);

        let problem = decode_problem(&fields, record.now);

        prop_assert!(ServerAddress::parse(&server_text).is_err());
        let expected = describe_malformed_field(&server_field);
        prop_assert_eq!(problem, Some(expected));
    }
}

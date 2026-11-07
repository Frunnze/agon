use std::net::SocketAddr;

use chrono::{DateTime, TimeDelta, Utc};
use orchestration_node::code_rendezvous::{
    MAXIMUM_RECORDED_DIRECT_ADDRESSES, decode_rendezvous_record,
    encode_rendezvous_record,
};
use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;

use crate::rendezvous_records::{
    CROWDED_ADDRESS_LIMIT, DIRECT_PREFIX, EXPIRY_PREFIX, LiveRecord,
    NO_SERVER_ACCEPTED_CODE, SERVER_PREFIX, crowded_peer_strategy,
    fields_named, live_record_strategy, moment_strategy,
    recorded_direct_addresses,
};
use crate::support::address_strategies::direct_address_strategy;
use crate::support::test_device::fail;

const FIELD_NAMES: [&str; 3] = ["expires", "server", "direct"];
const FIELD_SEPARATOR: char = '=';
const RECORD_STRING_LIMIT: usize = 255;
const NANOSECONDS_PER_SECOND: i64 = 1_000_000_000;
const LARGEST_DELAY_NANOSECONDS: i64 = 300 * NANOSECONDS_PER_SECOND;
const BOUNDARY_NANOSECONDS: i64 = 2 * NANOSECONDS_PER_SECOND;

type DirectAddresses = Vec<SocketAddr>;

fn parse_direct_values(direct_values: &[String]) -> DirectAddresses {
    let mut direct_addresses = Vec::new();
    for direct_value in direct_values {
        if let Ok(direct_address) = direct_value.parse() {
            direct_addresses.push(direct_address);
        }
    }
    direct_addresses
}

fn record_with_direct_fields(
    record: &LiveRecord,
    direct_addresses: &[SocketAddr],
) -> Vec<String> {
    let bare_server = record.server.without_direct_addresses();
    let mut fields = encode_rendezvous_record(&bare_server, record.expires_at);
    for direct_address in direct_addresses {
        fields.push(format!("{DIRECT_PREFIX}{direct_address}"));
    }
    fields
}

fn count_decoded_direct_addresses(
    fields: &[String],
    now: DateTime<Utc>,
) -> Option<usize> {
    let decoded = decode_rendezvous_record(fields, now).ok()?;
    Some(decoded.direct_addresses().len())
}

fn surplus_addresses_strategy() -> impl Strategy<Value = DirectAddresses> {
    prop::collection::vec(direct_address_strategy(), 0..CROWDED_ADDRESS_LIMIT)
}

proptest! {
    #[test]
    fn test_encode_rendezvous_record_property_writes_the_expiry_in_seconds(
        record in live_record_strategy(),
    ) {
        let expiry_values = fields_named(&record.fields, EXPIRY_PREFIX);

        let expected_value = record.expires_at.timestamp().to_string();
        prop_assert_eq!(expiry_values, vec![expected_value]);
    }

    #[test]
    fn test_encode_rendezvous_record_property_writes_a_bare_server(
        record in live_record_strategy(),
    ) {
        let server_values = fields_named(&record.fields, SERVER_PREFIX);

        prop_assert_eq!(server_values.len(), 1);
        let server = ServerAddress::parse(&server_values[0]).map_err(fail)?;
        prop_assert!(server.direct_addresses().is_empty());
        prop_assert_eq!(server, record.server.without_direct_addresses());
    }

    #[test]
    fn test_encode_rendezvous_record_property_writes_first_direct_addresses(
        record in live_record_strategy(),
    ) {
        let direct_values = fields_named(&record.fields, DIRECT_PREFIX);

        let written_addresses = parse_direct_values(&direct_values);
        prop_assert_eq!(written_addresses.len(), direct_values.len());
        let expected = recorded_direct_addresses(&record.server);
        prop_assert_eq!(written_addresses, expected);
    }

    #[test]
    fn test_encode_rendezvous_record_property_writes_only_named_fields(
        record in live_record_strategy(),
    ) {
        for field in &record.fields {
            let name_and_value = field.split_once(FIELD_SEPARATOR);
            let field_name = name_and_value.map(|parts| parts.0);
            let is_known = field_name
                .is_some_and(|field_name| FIELD_NAMES.contains(&field_name));
            prop_assert!(is_known, "{field}");
            prop_assert!(field.len() <= RECORD_STRING_LIMIT, "{field}");
        }
    }

    #[test]
    fn test_maximum_recorded_direct_addresses_property_bounds_the_writing(
        peer_address in crowded_peer_strategy(),
        expires_at in moment_strategy(),
    ) {
        let offered_count = peer_address.direct_addresses.len();
        let server = ServerAddress::Peer(peer_address);

        let fields = encode_rendezvous_record(&server, expires_at);

        let written_count = fields_named(&fields, DIRECT_PREFIX).len();
        let expected_count =
            offered_count.min(MAXIMUM_RECORDED_DIRECT_ADDRESSES);
        prop_assert_eq!(written_count, expected_count);
    }

    #[test]
    fn test_maximum_recorded_direct_addresses_property_bounds_the_reading(
        record in live_record_strategy(),
        direct_addresses in surplus_addresses_strategy(),
    ) {
        prop_assume!(matches!(record.server, ServerAddress::Peer(_)));
        let fields = record_with_direct_fields(&record, &direct_addresses);

        let decoded_count =
            count_decoded_direct_addresses(&fields, record.now);

        let fits_the_cap =
            direct_addresses.len() <= MAXIMUM_RECORDED_DIRECT_ADDRESSES;
        if fits_the_cap {
            prop_assert_eq!(decoded_count, Some(direct_addresses.len()));
        }
        let is_bounded = decoded_count
            .is_none_or(|count| count <= MAXIMUM_RECORDED_DIRECT_ADDRESSES);
        prop_assert!(is_bounded, "{decoded_count:?}");
    }

    #[test]
    fn test_maximum_recorded_direct_addresses_property_no_server_smuggling(
        record in live_record_strategy(),
        peer_address in crowded_peer_strategy(),
        direct_addresses in surplus_addresses_strategy(),
    ) {
        let smuggling_server = ServerAddress::Peer(peer_address);
        let mut fields = record_with_direct_fields(&record, &direct_addresses);
        fields.retain(|field| !field.starts_with(SERVER_PREFIX));
        fields.push(format!("{SERVER_PREFIX}{smuggling_server}"));

        let decoded_count =
            count_decoded_direct_addresses(&fields, record.now);

        let is_bounded = decoded_count
            .is_none_or(|count| count <= MAXIMUM_RECORDED_DIRECT_ADDRESSES);
        prop_assert!(is_bounded, "{decoded_count:?}");
    }

    #[test]
    fn test_decode_rendezvous_record_property_a_second_left_keeps_it_alive(
        record in live_record_strategy(),
        nanoseconds_left in NANOSECONDS_PER_SECOND..LARGEST_DELAY_NANOSECONDS,
    ) {
        let expires_at = record.now + TimeDelta::nanoseconds(nanoseconds_left);
        let fields = encode_rendezvous_record(&record.server, expires_at);

        let decoded = decode_rendezvous_record(&fields, record.now);

        prop_assert!(decoded.is_ok(), "{decoded:?}");
    }

    #[test]
    fn test_decode_rendezvous_record_property_never_alive_once_expired(
        record in live_record_strategy(),
        nanoseconds_late in 0..LARGEST_DELAY_NANOSECONDS,
    ) {
        let expires_at = record.now - TimeDelta::nanoseconds(nanoseconds_late);
        let fields = encode_rendezvous_record(&record.server, expires_at);

        let decoded = decode_rendezvous_record(&fields, record.now);

        let problem = decoded.err().map(|error| error.to_string());
        prop_assert_eq!(problem.as_deref(), Some(NO_SERVER_ACCEPTED_CODE));
    }

    #[test]
    fn test_decode_rendezvous_record_property_alive_only_before_expiry(
        record in live_record_strategy(),
        nanoseconds_offset in -BOUNDARY_NANOSECONDS..BOUNDARY_NANOSECONDS,
    ) {
        let expires_at =
            record.now + TimeDelta::nanoseconds(nanoseconds_offset);
        let fields = encode_rendezvous_record(&record.server, expires_at);

        let decoded = decode_rendezvous_record(&fields, record.now);

        if decoded.is_ok() {
            prop_assert!(record.now < expires_at);
        }
    }
}

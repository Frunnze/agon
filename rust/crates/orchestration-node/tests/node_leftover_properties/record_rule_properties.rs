use std::net::SocketAddr;

use chrono::{DateTime, TimeDelta, Utc};
use orchestration_node::code_rendezvous::{
    MAXIMUM_RECORDED_DIRECT_ADDRESSES, decode_rendezvous_record,
    encode_rendezvous_record,
};
use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;

use crate::rendezvous_records::{
    DIRECT_PREFIX, decode_problem, describe_malformed_field, moment_strategy,
};
use crate::support::address_strategies::direct_address_strategy;
use crate::support::test_device::fail;

const DIRECT_FIELD_NAME: &str = "direct";
const WEB_ADDRESS_PATTERN: &str = "https?://[a-z]{1,12}(\\.[a-z]{2,6})?";
const FIELD_PATTERN: &str = "(expires|server|direct)=\\PC{0,40}";
const INVALID_ADDRESS_START: &str = "the server address";
const LIFETIME_SECONDS: i64 = 300;
const MOST_FIELDS: usize = 6;

fn web_server_strategy() -> impl Strategy<Value = ServerAddress> {
    WEB_ADDRESS_PATTERN.prop_filter_map("the web address parses", |text| {
        ServerAddress::parse(&text).ok()
    })
}

fn expiry_strategy() -> impl Strategy<Value = (DateTime<Utc>, DateTime<Utc>)> {
    (moment_strategy(), 1..LIFETIME_SECONDS)
        .prop_map(|(now, seconds)| (now, now + TimeDelta::seconds(seconds)))
}

fn recorded_direct_strategy() -> impl Strategy<Value = Vec<SocketAddr>> {
    let count = 1..=MAXIMUM_RECORDED_DIRECT_ADDRESSES;
    prop::collection::vec(direct_address_strategy(), count)
}

fn add_direct_fields(
    fields: &[String],
    direct_addresses: &[SocketAddr],
) -> Vec<String> {
    let mut extended = fields.to_vec();
    for direct_address in direct_addresses {
        extended.push(format!("{DIRECT_PREFIX}{direct_address}"));
    }
    extended
}

proptest! {
    #[test]
    fn test_decode_rendezvous_record_property_a_web_server_takes_no_direct(
        server in web_server_strategy(),
        (now, expires_at) in expiry_strategy(),
        direct_addresses in recorded_direct_strategy(),
    ) {
        let fields = encode_rendezvous_record(&server, expires_at);
        let fields = add_direct_fields(&fields, &direct_addresses);

        let problem = decode_problem(&fields, now);

        let expected = describe_malformed_field(DIRECT_FIELD_NAME);
        prop_assert_eq!(problem, Some(expected));
    }

    #[test]
    fn test_decode_rendezvous_record_property_a_bare_web_server_opens(
        server in web_server_strategy(),
        (now, expires_at) in expiry_strategy(),
    ) {
        let fields = encode_rendezvous_record(&server, expires_at);

        let decoded = decode_rendezvous_record(&fields, now).map_err(fail)?;

        prop_assert_eq!(decoded.direct_addresses(), &[] as &[SocketAddr]);
        prop_assert_eq!(decoded, server);
    }

    #[test]
    fn test_parse_bare_server_property_never_names_an_invalid_address(
        fields in prop::collection::vec(FIELD_PATTERN, 1..MOST_FIELDS),
        now in moment_strategy(),
    ) {
        let problem = decode_problem(&fields, now).unwrap_or_default();

        let names_an_address = problem.starts_with(INVALID_ADDRESS_START);
        prop_assert!(!names_an_address, "{}", problem);
    }
}

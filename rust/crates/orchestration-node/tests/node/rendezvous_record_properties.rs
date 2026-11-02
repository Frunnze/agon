use chrono::{DateTime, TimeDelta, Utc};
use orchestration_node::code_rendezvous::{
    MAXIMUM_RECORDED_DIRECT_ADDRESSES, decode_rendezvous_record,
    encode_rendezvous_record,
};
use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;

use crate::support::address_strategies::server_address_strategy;

const NO_SERVER_ACCEPTED_CODE: &str = "no app server accepted the code";
const RECORD_FIELD_LIMIT: usize = 255;
const EARLIEST_SECONDS: i64 = 1_700_000_000;
const LATEST_SECONDS: i64 = 2_000_000_000;
const LIFETIME_SECONDS: i64 = 300;
const FIELD_COUNT_LIMIT: usize = 8;

fn moment_strategy() -> impl Strategy<Value = DateTime<Utc>> {
    (EARLIEST_SECONDS..LATEST_SECONDS).prop_map(|seconds| {
        DateTime::from_timestamp(seconds, 0).unwrap_or_default()
    })
}

fn limit_direct_addresses(address: &ServerAddress) -> ServerAddress {
    let kept: Vec<_> = address
        .direct_addresses()
        .iter()
        .take(MAXIMUM_RECORDED_DIRECT_ADDRESSES)
        .copied()
        .collect();
    address
        .without_direct_addresses()
        .with_direct_addresses(&kept)
}

proptest! {
    #[test]
    fn test_decode_rendezvous_record_property_a_live_record_round_trips(
        address in server_address_strategy(),
        now in moment_strategy(),
        seconds_left in 1..LIFETIME_SECONDS,
    ) {
        let expires_at = now + TimeDelta::seconds(seconds_left);

        let fields = encode_rendezvous_record(&address, expires_at);
        let decoded = decode_rendezvous_record(&fields, now);

        let expected = limit_direct_addresses(&address);
        let decoded_text = decoded.map_err(|error| error.to_string());
        prop_assert_eq!(decoded_text, Ok(expected));
        let fits_the_record =
            fields.iter().all(|field| field.len() <= RECORD_FIELD_LIMIT);
        prop_assert!(fits_the_record);
    }

    #[test]
    fn test_decode_rendezvous_record_property_an_expired_record_opens_nothing(
        address in server_address_strategy(),
        now in moment_strategy(),
        seconds_late in 0..LIFETIME_SECONDS,
    ) {
        let expires_at = now - TimeDelta::seconds(seconds_late);

        let fields = encode_rendezvous_record(&address, expires_at);
        let decoded = decode_rendezvous_record(&fields, now);

        let problem = decoded.err().map(|error| error.to_string());
        prop_assert_eq!(problem.as_deref(), Some(NO_SERVER_ACCEPTED_CODE));
    }

    #[test]
    fn test_decode_rendezvous_record_property_arbitrary_fields_never_panic(
        fields in prop::collection::vec("\\PC{0,60}", 0..FIELD_COUNT_LIMIT),
        now in moment_strategy(),
    ) {
        let decoded = decode_rendezvous_record(&fields, now);

        if fields.is_empty() {
            let problem = decoded.err().map(|error| error.to_string());
            prop_assert_eq!(problem.as_deref(), Some(NO_SERVER_ACCEPTED_CODE));
        }
    }
}

#[test]
fn test_decode_rendezvous_record_property_a_withdrawn_record_opens_nothing() {
    let decoded = decode_rendezvous_record(&[], Utc::now());

    let problem = decoded.err().map(|error| error.to_string());
    assert_eq!(problem.as_deref(), Some(NO_SERVER_ACCEPTED_CODE));
}

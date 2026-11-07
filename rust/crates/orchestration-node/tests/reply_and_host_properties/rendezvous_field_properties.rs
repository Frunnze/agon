use std::net::SocketAddr;

use orchestration_node::code_rendezvous::decode_rendezvous_record;
use proptest::prelude::*;
use proptest::sample::Index;

use crate::rendezvous_records::{
    DIRECT_PREFIX, EXPIRY_PREFIX, SERVER_PREFIX, decode_problem,
    describe_malformed_field, live_record_strategy, recorded_direct_addresses,
    shuffled_live_record_strategy,
};
use crate::support::test_device::fail;

const KNOWN_FIELD_NAMES: [&str; 3] = ["expires", "server", "direct"];
const FIELD_NAME_PATTERN: &str = "[a-z]{0,10}";
const FIELD_VALUE_PATTERN: &str = "\\PC{0,20}";
const SEPARATOR_FREE_PATTERN: &str = "[^=]{0,30}";
const REQUIRED_PREFIXES: [&str; 2] = [EXPIRY_PREFIX, SERVER_PREFIX];
const PREFIX_SEPARATOR: char = '=';

fn sort_addresses(direct_addresses: &[SocketAddr]) -> Vec<SocketAddr> {
    let mut sorted = direct_addresses.to_vec();
    sorted.sort_unstable();
    sorted
}

fn insert_field(
    fields: &[String],
    inserted_field: String,
    position: Index,
) -> Vec<String> {
    let mut changed_fields = fields.to_vec();
    let insert_index = position.index(fields.len() + 1);
    changed_fields.insert(insert_index, inserted_field);
    changed_fields
}

fn is_unknown_field_name(field_name: &str) -> bool {
    !KNOWN_FIELD_NAMES.contains(&field_name)
}

fn is_unreadable_seconds(text: &str) -> bool {
    text.parse::<i64>().is_err()
}

fn is_unreadable_address(text: &str) -> bool {
    text.parse::<SocketAddr>().is_err()
}

fn join_field(name_and_value: (String, String)) -> String {
    let (field_name, field_value) = name_and_value;
    format!("{field_name}{PREFIX_SEPARATOR}{field_value}")
}

fn unknown_field_strategy() -> impl Strategy<Value = String> {
    let unknown_name = FIELD_NAME_PATTERN
        .prop_filter("unknown", |name| is_unknown_field_name(name));
    (unknown_name, FIELD_VALUE_PATTERN).prop_map(join_field)
}

fn unreadable_field_strategy() -> impl Strategy<Value = String> {
    let unreadable_expiry = FIELD_VALUE_PATTERN
        .prop_filter("not seconds", |text| is_unreadable_seconds(text))
        .prop_map(|text| format!("{EXPIRY_PREFIX}{text}"));
    let unreadable_direct = FIELD_VALUE_PATTERN
        .prop_filter("not an address", |text| is_unreadable_address(text))
        .prop_map(|text| format!("{DIRECT_PREFIX}{text}"));
    prop_oneof![unreadable_expiry, unreadable_direct]
}

fn required_prefix_strategy() -> impl Strategy<Value = &'static str> {
    prop::sample::select(REQUIRED_PREFIXES.to_vec())
}

proptest! {
    #[test]
    fn test_decode_rendezvous_record_property_field_order_does_not_matter(
        (record, shuffled_fields) in shuffled_live_record_strategy(),
    ) {
        let decoded = decode_rendezvous_record(&shuffled_fields, record.now)
            .map_err(fail)?;

        let bare_server = record.server.without_direct_addresses();
        prop_assert_eq!(decoded.without_direct_addresses(), bare_server);
        let expected = recorded_direct_addresses(&record.server);
        let decoded_addresses = sort_addresses(decoded.direct_addresses());
        prop_assert_eq!(decoded_addresses, sort_addresses(&expected));
    }

    #[test]
    fn test_decode_rendezvous_record_property_a_repeated_field_is_malformed(
        record in live_record_strategy(),
        repeated_prefix in required_prefix_strategy(),
        position in any::<Index>(),
    ) {
        let repeated_field = record
            .fields
            .iter()
            .find(|field| field.starts_with(repeated_prefix))
            .cloned()
            .unwrap_or_default();
        let fields =
            insert_field(&record.fields, repeated_field.clone(), position);

        let problem = decode_problem(&fields, record.now);

        let expected = describe_malformed_field(&repeated_field);
        prop_assert_eq!(problem, Some(expected));
    }

    #[test]
    fn test_describe_malformed_property_names_a_field_without_a_separator(
        record in live_record_strategy(),
        separator_free_field in SEPARATOR_FREE_PATTERN,
        position in any::<Index>(),
    ) {
        let expected = describe_malformed_field(&separator_free_field);
        let fields =
            insert_field(&record.fields, separator_free_field, position);

        let problem = decode_problem(&fields, record.now);

        prop_assert_eq!(problem, Some(expected));
    }

    #[test]
    fn test_describe_malformed_property_names_a_field_of_an_unknown_name(
        record in live_record_strategy(),
        unknown_field in unknown_field_strategy(),
        position in any::<Index>(),
    ) {
        let expected = describe_malformed_field(&unknown_field);
        let fields = insert_field(&record.fields, unknown_field, position);

        let problem = decode_problem(&fields, record.now);

        prop_assert_eq!(problem, Some(expected));
    }

    #[test]
    fn test_describe_malformed_property_names_a_missing_required_field(
        record in live_record_strategy(),
        missing_prefix in required_prefix_strategy(),
    ) {
        let mut fields = record.fields.clone();
        fields.retain(|field| !field.starts_with(missing_prefix));

        let problem = decode_problem(&fields, record.now);

        let missing_name = missing_prefix.trim_end_matches(PREFIX_SEPARATOR);
        prop_assert_eq!(problem, Some(describe_malformed_field(missing_name)));
    }

    #[test]
    fn test_describe_malformed_property_names_an_unreadable_value(
        record in live_record_strategy(),
        unreadable_field in unreadable_field_strategy(),
        position in any::<Index>(),
    ) {
        let expected = describe_malformed_field(&unreadable_field);
        let mut fields = record.fields.clone();
        if unreadable_field.starts_with(EXPIRY_PREFIX) {
            fields.retain(|field| !field.starts_with(EXPIRY_PREFIX));
        }
        let fields = insert_field(&fields, unreadable_field, position);

        let problem = decode_problem(&fields, record.now);

        prop_assert_eq!(problem, Some(expected));
    }
}

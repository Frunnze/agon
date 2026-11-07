use std::collections::BTreeMap;

use orchestration_node::command_reply::{encode_reply, render_reply};
use orchestration_node::node_error::NodeError;
use proptest::prelude::*;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::reply_values::{json_value_strategy, tricky_text_strategy};
use crate::support::test_device::{fail, is_defined_reply};

const ENTRY_LIMIT: usize = 4;
const UNNAMED_KEY_LIMIT: usize = 4;
const ERROR_FIELD: &str = "error";

type SampleViewParts = (
    String,
    u64,
    Vec<String>,
    Option<String>,
    BTreeMap<String, i64>,
);
type ByteKeyedView = BTreeMap<Vec<u8>, u8>;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
struct SampleView {
    name: String,
    count: u64,
    tags: Vec<String>,
    note: Option<String>,
    nested: BTreeMap<String, i64>,
}

fn build_sample_view(parts: SampleViewParts) -> SampleView {
    let (name, count, tags, note, nested) = parts;
    SampleView {
        name,
        count,
        tags,
        note,
        nested,
    }
}

fn sample_view_strategy() -> impl Strategy<Value = SampleView> {
    let tags = prop::collection::vec(tricky_text_strategy(), 0..ENTRY_LIMIT);
    let nested = prop::collection::btree_map(
        tricky_text_strategy(),
        any::<i64>(),
        0..ENTRY_LIMIT,
    );
    let note = prop::option::of(tricky_text_strategy());
    (tricky_text_strategy(), any::<u64>(), tags, note, nested)
        .prop_map(build_sample_view)
}

fn byte_keyed_view_strategy() -> impl Strategy<Value = ByteKeyedView> {
    let byte_key = prop::collection::vec(any::<u8>(), 0..ENTRY_LIMIT);
    prop::collection::btree_map(byte_key, any::<u8>(), 1..UNNAMED_KEY_LIMIT)
}

proptest! {
    #[test]
    fn test_encode_reply_property_a_view_round_trips(
        view in sample_view_strategy(),
    ) {
        let encoded = encode_reply(&view).map_err(fail)?;

        let decoded: SampleView =
            serde_json::from_value(encoded).map_err(fail)?;
        prop_assert_eq!(decoded, view);
    }

    #[test]
    fn test_encode_reply_property_matches_the_json_text_of_the_view(
        view in sample_view_strategy(),
    ) {
        let view_text = serde_json::to_string(&view).map_err(fail)?;
        let expected: Value = serde_json::from_str(&view_text).map_err(fail)?;

        let encoded = encode_reply(&view).map_err(fail)?;

        prop_assert_eq!(encoded, expected);
    }

    #[test]
    fn test_encode_reply_property_a_json_value_is_kept_unchanged(
        reply_value in json_value_strategy(),
    ) {
        let encoded = encode_reply(&reply_value).map_err(fail)?;

        prop_assert_eq!(encoded, reply_value);
    }

    #[test]
    fn test_encode_reply_property_a_view_json_cannot_hold_is_refused(
        view in byte_keyed_view_strategy(),
    ) {
        let encoded = encode_reply(&view);

        let is_json_problem = matches!(encoded, Err(NodeError::Json(_)));
        prop_assert!(is_json_problem, "{encoded:?}");
        let reply: Value =
            serde_json::from_str(&render_reply(&encoded)).map_err(fail)?;
        prop_assert!(is_defined_reply(&reply));
        prop_assert!(reply.get(ERROR_FIELD).is_some());
    }

    #[test]
    fn test_encode_reply_property_only_numbers_json_can_hold_are_kept(
        number in prop_oneof![
            any::<u64>().prop_map(u128::from),
            any::<u128>(),
        ],
    ) {
        let encoded = encode_reply(&number);

        let fitting_number = u64::try_from(number).ok();
        let encoded_number = encoded.as_ref().ok().and_then(Value::as_u64);
        prop_assert_eq!(encoded_number, fitting_number);
        let is_json_problem = matches!(encoded, Err(NodeError::Json(_)));
        prop_assert_eq!(is_json_problem, fitting_number.is_none());
    }
}

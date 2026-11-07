use proptest::prelude::*;
use serde_json::{Map, Value};

const TRICKY_CHARACTERS: [char; 12] = [
    '\n', '\r', '\t', '"', '\\', '\u{0}', '\u{1b}', '\u{2028}', '\u{2029}',
    '\u{feff}', 'é', '𝄞',
];
const LONGEST_TEXT: usize = 24;
const NESTING_DEPTH: u32 = 3;
const DESIRED_NODE_COUNT: u32 = 24;
const EXPECTED_BRANCH_SIZE: u32 = 4;
const NESTED_ENTRY_LIMIT: usize = 4;
const LARGEST_FRACTION_BITS: u32 = 8;

pub fn tricky_text_strategy() -> impl Strategy<Value = String> {
    let tricky_character =
        prop::sample::select(TRICKY_CHARACTERS.to_vec()).boxed();
    let any_character = any::<char>().boxed();
    let character = prop_oneof![tricky_character, any_character];
    prop::collection::vec(character, 0..LONGEST_TEXT)
        .prop_map(String::from_iter)
}

pub fn json_value_strategy() -> impl Strategy<Value = Value> {
    let leaf = prop_oneof![
        Just(Value::Null),
        any::<bool>().prop_map(Value::Bool),
        any::<i64>().prop_map(Value::from),
        any::<u64>().prop_map(Value::from),
        exact_number_strategy(),
        tricky_text_strategy().prop_map(Value::String),
    ];
    leaf.prop_recursive(
        NESTING_DEPTH,
        DESIRED_NODE_COUNT,
        EXPECTED_BRANCH_SIZE,
        nest_json_values,
    )
}

fn nest_json_values(inner: BoxedStrategy<Value>) -> BoxedStrategy<Value> {
    let entries = (tricky_text_strategy(), inner.clone());
    let objects = prop::collection::vec(entries, 0..NESTED_ENTRY_LIMIT)
        .prop_map(build_object);
    let arrays = prop::collection::vec(inner, 0..NESTED_ENTRY_LIMIT)
        .prop_map(Value::Array);
    prop_oneof![objects, arrays].boxed()
}

fn exact_number_strategy() -> impl Strategy<Value = Value> {
    (any::<i32>(), 0..LARGEST_FRACTION_BITS).prop_map(build_exact_fraction)
}

fn build_exact_fraction(whole_and_fraction_bits: (i32, u32)) -> Value {
    let (whole, fraction_bits) = whole_and_fraction_bits;
    let divisor = f64::from(1_u32 << fraction_bits);
    Value::from(f64::from(whole) / divisor)
}

fn build_object(entries: Vec<(String, Value)>) -> Value {
    let mut object = Map::new();
    for (key, entry_value) in entries {
        object.insert(key, entry_value);
    }
    Value::Object(object)
}

use std::collections::BTreeMap;

use orchestration_node::commands::command_names;
use proptest::prelude::*;
use serde_json::{Map, Value};

const DEEPEST_FUZZ_VALUE: u32 = 3;
const WIDEST_FUZZ_VALUE: u32 = 24;
const MOST_FUZZ_ITEMS: u32 = 6;
const MOST_FUZZ_ARGUMENTS: usize = 4;
const COMMAND_FIELD: &str = "command";
const FUZZ_ARGUMENT_NAMES: [&str; 12] = [
    "workspace_id",
    "project_id",
    "task_id",
    "run_id",
    "device_id",
    "code",
    "name",
    "text",
    "after",
    "decision",
    "schedule",
    "workflow",
];

type NamedArgument = (&'static str, Value);

pub fn arbitrary_json() -> impl Strategy<Value = Value> {
    let leaf = prop_oneof![
        Just(Value::Null),
        any::<bool>().prop_map(Value::Bool),
        any::<i64>().prop_map(Value::from),
        "\\PC{0,24}".prop_map(Value::String),
    ];
    leaf.prop_recursive(
        DEEPEST_FUZZ_VALUE,
        WIDEST_FUZZ_VALUE,
        MOST_FUZZ_ITEMS,
        nest_json,
    )
}

pub fn arbitrary_command_strategy() -> impl Strategy<Value = Value> {
    let argument = (
        proptest::sample::select(FUZZ_ARGUMENT_NAMES.to_vec()),
        arbitrary_json(),
    );
    let arguments =
        proptest::collection::vec(argument, 0..MOST_FUZZ_ARGUMENTS);
    (proptest::sample::select(command_names()), arguments)
        .prop_map(build_command)
}

fn build_command(
    (name, arguments): (&'static str, Vec<NamedArgument>),
) -> Value {
    let mut command = Map::new();
    command.insert(COMMAND_FIELD.to_owned(), Value::from(name));
    for (argument_name, argument_value) in arguments {
        command.insert(argument_name.to_owned(), argument_value);
    }
    Value::Object(command)
}

fn nest_json(inner: BoxedStrategy<Value>) -> impl Strategy<Value = Value> {
    let arrays =
        proptest::collection::vec(inner.clone(), 0..4).prop_map(Value::Array);
    let objects = proptest::collection::btree_map("[a-z_]{1,12}", inner, 0..4)
        .prop_map(build_object);
    prop_oneof![arrays, objects]
}

fn build_object(fields: BTreeMap<String, Value>) -> Value {
    Value::Object(fields.into_iter().collect())
}

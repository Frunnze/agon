use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};

use crate::account_steps::{
    PARSING_CASES, ROLE_NAMES, account_command_name_strategy,
    harmless_command, read_error, shared_fresh_device, with_field,
};
use crate::support::command_strategies::arbitrary_json;

const KNOWN_FIELDS: [&str; 7] = [
    "command",
    "after",
    "server_address",
    "setup_code",
    "device_name",
    "role",
    "workspace_name",
];
const REQUIRED_ARGUMENTS: [(&str, &str); 9] = [
    ("create_account", "server_address"),
    ("create_account", "setup_code"),
    ("create_account", "device_name"),
    ("create_account", "role"),
    ("create_account", "workspace_name"),
    ("create_hosted_account", "workspace_name"),
    ("create_hosted_account", "device_name"),
    ("create_hosted_account", "role"),
    ("poll_events", "after"),
];
const ROLE_ARGUMENTS: [&str; 2] = ["create_account", "create_hosted_account"];

fn unknown_field_strategy() -> impl Strategy<Value = String> {
    "[a-z_]{1,16}".prop_filter("a field the command does not know", |field| {
        !KNOWN_FIELDS.contains(&field.as_str())
    })
}

fn wrongly_typed_value_strategy() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        any::<bool>().prop_map(Value::Bool),
        (i64::MIN..0).prop_map(Value::from),
        (-1.0e6_f64..1.0e6).prop_map(|number| json!(number + 0.5)),
        proptest::collection::vec(arbitrary_json(), 0..3)
            .prop_map(Value::Array),
        Just(json!({ "value": 1 })),
    ]
}

fn unknown_role_strategy() -> impl Strategy<Value = String> {
    "[a-zA-Z_ ]{0,20}".prop_filter("a role the node does not know", |role| {
        !ROLE_NAMES.contains(&role.as_str())
    })
}

fn invalid_arguments_prefix(name: &str) -> String {
    format!("invalid arguments for {name}:")
}

fn remove_field(command: &Value, field: &str) -> Value {
    let mut reduced = command.clone();
    if let Some(fields) = reduced.as_object_mut() {
        fields.remove(field);
    }
    reduced
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PARSING_CASES))]

    #[test]
    fn test_account_command_property_refuses_unknown_fields_on_every_variant(
        name in account_command_name_strategy(),
        field in unknown_field_strategy(),
        field_value in arbitrary_json(),
    ) {
        let device = shared_fresh_device()?;
        let command = with_field(&harmless_command(name), &field, field_value);

        let reply = device.send(&command);

        let error = read_error(&reply);
        prop_assert!(
            error.starts_with(&invalid_arguments_prefix(name)),
            "{} gave {}",
            command,
            reply
        );
        prop_assert!(error.contains(&field), "{error}");
    }

    #[test]
    fn test_account_command_property_refuses_a_missing_argument(
        (name, field) in select(REQUIRED_ARGUMENTS.to_vec()),
    ) {
        let device = shared_fresh_device()?;
        let command = remove_field(&harmless_command(name), field);

        let reply = device.send(&command);

        let error = read_error(&reply);
        prop_assert!(
            error.starts_with(&invalid_arguments_prefix(name)),
            "{reply}"
        );
        let missing = format!("missing field `{field}`");
        prop_assert!(error.contains(&missing), "{error}");
    }

    #[test]
    fn test_account_command_property_refuses_wrongly_typed_arguments(
        (name, field) in select(REQUIRED_ARGUMENTS.to_vec()),
        wrong_value in wrongly_typed_value_strategy(),
    ) {
        let device = shared_fresh_device()?;
        let command = with_field(&harmless_command(name), field, wrong_value);

        let reply = device.send(&command);

        let error = read_error(&reply);
        prop_assert!(
            error.starts_with(&invalid_arguments_prefix(name)),
            "{} gave {}",
            command,
            reply
        );
    }

    #[test]
    fn test_account_command_property_refuses_a_role_it_does_not_know(
        name in select(ROLE_ARGUMENTS.to_vec()),
        role in unknown_role_strategy(),
    ) {
        let device = shared_fresh_device()?;
        let command = with_field(&harmless_command(name), "role", json!(role));

        let reply = device.send(&command);

        let error = read_error(&reply);
        prop_assert!(
            error.starts_with(&invalid_arguments_prefix(name)),
            "{reply}"
        );
        prop_assert!(error.contains("unknown variant"), "{error}");
    }
}

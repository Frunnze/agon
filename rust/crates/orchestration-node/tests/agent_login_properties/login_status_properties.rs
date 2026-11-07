use std::fs;

use orchestration_node::agent_login::{ClaudeLogin, interpret_login_answer};
use proptest::prelude::*;
use serde_json::{Map, Value, json};

use crate::login_steps::{
    CLAUDE_LOGIN_FIELD, CONTAINER_PLACE, LOCAL_PLACE, LOGGED_IN_RECORD_NAME,
    LOGIN_CASES, any_login_code, finish_login, start_nodes,
    start_nodes_without_claude,
};
use crate::secret_rules::any_white_space_padding;
use crate::support::test_device::fail;

const LOGGED_IN_FIELD: &str = "loggedIn";
const LOGGED_IN_NAME: &str = "logged_in";
const NOT_LOGGED_IN_NAME: &str = "not_logged_in";
const NOT_INSTALLED_NAME: &str = "not_installed";
const MAXIMUM_STATUS_READS: usize = 3;

fn any_other_fields() -> impl Strategy<Value = Map<String, Value>> {
    let field_value = prop_oneof![
        "[a-z0-9 .]{0,12}".prop_map(Value::String),
        any::<bool>().prop_map(Value::Bool),
        any::<i32>().prop_map(Value::from),
    ];
    proptest::collection::btree_map("[a-zA-Z]{1,10}", field_value, 0..5)
        .prop_map(|fields| fields.into_iter().collect())
}

fn any_non_boolean() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        "true|false|yes|[a-z]{0,6}".prop_map(Value::String),
        any::<i64>().prop_map(Value::from),
        Just(json!([true])),
        Just(json!({ "value": true })),
    ]
}

fn expected_login(is_logged_in: bool) -> ClaudeLogin {
    if is_logged_in {
        return ClaudeLogin::LoggedIn;
    }
    ClaudeLogin::NotLoggedIn
}

fn build_answer(
    mut other_fields: Map<String, Value>,
    logged_in: Value,
) -> Value {
    other_fields.insert(LOGGED_IN_FIELD.to_owned(), logged_in);
    Value::Object(other_fields)
}

proptest! {
    #[test]
    fn test_interpret_login_answer_property_padding_is_ignored(
        is_logged_in in any::<bool>(),
        other_fields in any_other_fields(),
        padding_before in any_white_space_padding(),
        padding_after in any_white_space_padding(),
    ) {
        let answer = build_answer(other_fields, Value::Bool(is_logged_in));
        let padded = format!("{padding_before}{answer}{padding_after}");

        let login = interpret_login_answer(&padded).map_err(fail)?;

        prop_assert_eq!(login, expected_login(is_logged_in));
    }

    #[test]
    fn test_interpret_login_answer_property_a_non_boolean_is_refused(
        logged_in in any_non_boolean(),
        other_fields in any_other_fields(),
    ) {
        let answer = build_answer(other_fields, logged_in);

        prop_assert!(interpret_login_answer(&answer.to_string()).is_err());
    }

    #[test]
    fn test_interpret_login_answer_property_a_missing_field_is_refused(
        mut other_fields in any_other_fields(),
    ) {
        other_fields.remove(LOGGED_IN_FIELD);
        let answer = Value::Object(other_fields);

        prop_assert!(interpret_login_answer(&answer.to_string()).is_err());
    }

    #[test]
    fn test_interpret_login_answer_property_only_the_field_decides(
        is_logged_in in any::<bool>(),
        first_fields in any_other_fields(),
        second_fields in any_other_fields(),
    ) {
        let logged_in = Value::Bool(is_logged_in);
        let first = build_answer(first_fields, logged_in.clone());
        let second = build_answer(second_fields, logged_in);

        let first_login =
            interpret_login_answer(&first.to_string()).map_err(fail)?;
        let second_login =
            interpret_login_answer(&second.to_string()).map_err(fail)?;

        prop_assert_eq!(first_login, second_login);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LOGIN_CASES))]

    #[test]
    fn test_read_claude_login_property_a_fresh_computer_is_not_logged_in(
        reads in 1..=MAXIMUM_STATUS_READS,
    ) {
        let nodes = start_nodes()?;

        for _ in 0..reads {
            let status = nodes.read_login_status().map_err(fail)?;
            prop_assert_eq!(&status[CLAUDE_LOGIN_FIELD], NOT_LOGGED_IN_NAME);
        }
    }

    #[test]
    fn test_read_claude_login_property_follows_the_program_answer(
        code in any_login_code(),
        reads in 1..=MAXIMUM_STATUS_READS,
    ) {
        let nodes = start_nodes()?;
        finish_login(&nodes, LOCAL_PLACE, &code)?;

        for _ in 0..reads {
            let status = nodes.read_login_status().map_err(fail)?;
            prop_assert_eq!(&status[CLAUDE_LOGIN_FIELD], LOGGED_IN_NAME);
        }
        let logged_in_record =
            nodes.records.path().join(LOGGED_IN_RECORD_NAME);
        fs::remove_file(logged_in_record).map_err(fail)?;
        let status = nodes.read_login_status().map_err(fail)?;
        prop_assert_eq!(&status[CLAUDE_LOGIN_FIELD], NOT_LOGGED_IN_NAME);
    }

    #[test]
    fn test_read_claude_login_property_a_container_login_leaves_it_alone(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        finish_login(&nodes, CONTAINER_PLACE, &code)?;

        let status = nodes.read_login_status().map_err(fail)?;
        prop_assert_eq!(&status[CLAUDE_LOGIN_FIELD], NOT_LOGGED_IN_NAME);
    }

    #[test]
    fn test_read_claude_login_property_a_missing_program_is_not_installed(
        reads in 1..=MAXIMUM_STATUS_READS,
    ) {
        let nodes = start_nodes_without_claude()?;

        for _ in 0..reads {
            let status = nodes.read_login_status().map_err(fail)?;
            prop_assert_eq!(&status[CLAUDE_LOGIN_FIELD], NOT_INSTALLED_NAME);
        }
    }
}

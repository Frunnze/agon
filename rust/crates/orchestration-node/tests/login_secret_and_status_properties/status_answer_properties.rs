use orchestration_node::agent_login::interpret_login_answer;
use proptest::prelude::*;
use serde_json::{Value, json};

const MAXIMUM_LIST_LENGTH: usize = 4;

fn any_answer_value() -> impl Strategy<Value = Value> {
    prop_oneof![
        any::<bool>().prop_map(Value::Bool),
        "[a-z ]{0,12}".prop_map(Value::String),
        any::<i32>().prop_map(|number| json!(number)),
        Just(Value::Null),
    ]
}

fn any_list_answer() -> impl Strategy<Value = Value> {
    proptest::collection::vec(any_answer_value(), 0..=MAXIMUM_LIST_LENGTH)
        .prop_map(Value::Array)
}

proptest! {
    #[test]
    fn test_interpret_login_answer_property_a_list_is_never_a_status(
        list in any_list_answer(),
    ) {
        let answer = list.to_string();

        prop_assert!(interpret_login_answer(&answer).is_err(), "{answer}");
    }

    #[test]
    fn test_interpret_login_answer_property_a_bare_value_is_refused(
        bare in any_answer_value(),
    ) {
        let answer = bare.to_string();

        prop_assert!(interpret_login_answer(&answer).is_err(), "{answer}");
    }

    #[test]
    fn test_interpret_login_answer_property_a_nested_field_is_refused(
        is_logged_in in any::<bool>(),
    ) {
        let answer = json!({ "status": { "loggedIn": is_logged_in } });

        prop_assert!(interpret_login_answer(&answer.to_string()).is_err());
    }
}

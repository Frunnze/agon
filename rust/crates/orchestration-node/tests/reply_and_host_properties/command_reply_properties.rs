use orchestration_node::command_reply::{
    render_error_reply, render_reply, render_success_reply,
};
use orchestration_node::node_error::NodeError;
use proptest::prelude::*;
use proptest::strategy::LazyJust;
use serde_json::{Map, Value};

use crate::reply_values::{json_value_strategy, tricky_text_strategy};
use crate::support::test_device::{fail, is_defined_reply};

const SUCCESS_FIELD: &str = "ok";
const ERROR_FIELD: &str = "error";
const LINE_BREAKS: [char; 2] = ['\n', '\r'];

type CommandOutcome = Result<Value, NodeError>;

fn parse_reply(reply_text: &str) -> Result<Value, TestCaseError> {
    serde_json::from_str(reply_text).map_err(fail)
}

fn is_one_line(reply_text: &str) -> bool {
    !reply_text.contains(LINE_BREAKS)
}

fn node_error_strategy() -> impl Strategy<Value = NodeError> {
    prop_oneof![
        tricky_text_strategy().prop_map(NodeError::InvalidCommand),
        tricky_text_strategy().prop_map(NodeError::Startup),
        tricky_text_strategy().prop_map(NodeError::MalformedRendezvousRecord),
        LazyJust::new(|| NodeError::NoServerAcceptedCode),
    ]
}

fn command_outcome_strategy() -> impl Strategy<Value = CommandOutcome> {
    prop_oneof![
        json_value_strategy().prop_map(Ok),
        node_error_strategy().prop_map(Err),
    ]
}

proptest! {
    #[test]
    fn test_render_success_reply_property_parses_back_to_the_same_success(
        success in json_value_strategy(),
    ) {
        let reply = parse_reply(&render_success_reply(&success))?;

        let field_count = reply.as_object().map(Map::len);
        prop_assert_eq!(field_count, Some(1));
        prop_assert_eq!(reply.get(SUCCESS_FIELD), Some(&success));
    }

    #[test]
    fn test_render_success_reply_property_stays_on_one_line(
        success in json_value_strategy(),
    ) {
        let reply_text = render_success_reply(&success);

        prop_assert!(is_one_line(&reply_text), "{reply_text}");
    }

    #[test]
    fn test_render_success_reply_property_an_error_shaped_success_stays_ok(
        message in tricky_text_strategy(),
    ) {
        let mut error_shaped = Map::new();
        error_shaped.insert(ERROR_FIELD.to_owned(), Value::String(message));
        let success = Value::Object(error_shaped);

        let reply = parse_reply(&render_success_reply(&success))?;

        prop_assert!(is_defined_reply(&reply));
        prop_assert_eq!(reply.get(ERROR_FIELD), None);
        prop_assert_eq!(reply.get(SUCCESS_FIELD), Some(&success));
    }

    #[test]
    fn test_render_error_reply_property_parses_back_to_the_same_message(
        message in tricky_text_strategy(),
    ) {
        let reply = parse_reply(&render_error_reply(&message))?;

        let read_message = reply.get(ERROR_FIELD).and_then(Value::as_str);
        prop_assert_eq!(read_message, Some(message.as_str()));
    }

    #[test]
    fn test_render_error_reply_property_stays_on_one_line(
        message in tricky_text_strategy(),
    ) {
        let reply_text = render_error_reply(&message);

        prop_assert!(is_one_line(&reply_text), "{reply_text}");
    }

    #[test]
    fn test_render_error_reply_property_is_a_defined_error_never_a_success(
        message in tricky_text_strategy(),
    ) {
        let reply = parse_reply(&render_error_reply(&message))?;

        prop_assert!(is_defined_reply(&reply));
        prop_assert_eq!(reply.get(SUCCESS_FIELD), None);
    }

    #[test]
    fn test_render_error_reply_property_tells_different_messages_apart(
        first_message in tricky_text_strategy(),
        second_message in tricky_text_strategy(),
    ) {
        let first_reply = render_error_reply(&first_message);
        let second_reply = render_error_reply(&second_message);

        let replies_match = first_reply == second_reply;
        prop_assert_eq!(replies_match, first_message == second_message);
    }

    #[test]
    fn test_render_reply_property_a_success_renders_like_a_success_reply(
        success in json_value_strategy(),
    ) {
        let expected_reply = render_success_reply(&success);

        let reply_text = render_reply(&Ok(success));

        prop_assert_eq!(reply_text, expected_reply);
    }

    #[test]
    fn test_render_reply_property_an_error_renders_its_own_message(
        error in node_error_strategy(),
    ) {
        let expected_message = error.to_string();

        let reply = parse_reply(&render_reply(&Err(error)))?;

        let read_message = reply.get(ERROR_FIELD).and_then(Value::as_str);
        prop_assert_eq!(read_message, Some(expected_message.as_str()));
    }

    #[test]
    fn test_render_reply_property_every_outcome_is_one_defined_line(
        outcome in command_outcome_strategy(),
    ) {
        let reply_text = render_reply(&outcome);
        let reply = parse_reply(&reply_text)?;

        prop_assert!(is_one_line(&reply_text), "{reply_text}");
        prop_assert!(is_defined_reply(&reply));
        let has_success = reply.get(SUCCESS_FIELD).is_some();
        prop_assert_eq!(has_success, outcome.is_ok());
    }
}

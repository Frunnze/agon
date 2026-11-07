use orchestration_node::command_reply::{
    render_error_reply, render_node_error_reply, render_reply,
};
use orchestration_node::node_error::NodeError;
use proptest::prelude::*;
use serde_json::Value;

use crate::error_kind_samples::{
    ERROR_FIELD, ERROR_KIND_FIELD, ErrorRecipe, NO_ACCOUNT_KIND,
    SUCCESS_FIELD, error_recipe_strategy, is_one_line,
    kindless_recipe_strategy, no_account_reply, read_kind,
};
use crate::support::command_strategies::arbitrary_json;
use crate::support::test_device::{fail, is_defined_reply};

const MOST_RENDERINGS: usize = 4;

fn parse_reply(reply_text: &str) -> Result<Value, TestCaseError> {
    serde_json::from_str(reply_text).map_err(fail)
}

fn render_recipe(recipe: &ErrorRecipe) -> Result<Value, TestCaseError> {
    parse_reply(&render_node_error_reply(&recipe.build()))
}

proptest! {
    #[test]
    fn test_render_node_error_reply_property_no_account_reply_is_exact(
        renderings in 1..MOST_RENDERINGS,
    ) {
        for _ in 0..renderings {
            let reply_text = render_node_error_reply(&NodeError::NoAccount);

            prop_assert_eq!(parse_reply(&reply_text)?, no_account_reply());
            prop_assert!(is_one_line(&reply_text), "{}", reply_text);
        }
    }

    #[test]
    fn test_render_node_error_reply_property_kindless_errors_stay_plain(
        recipe in kindless_recipe_strategy(),
    ) {
        let error = recipe.build();
        let plain_reply = render_error_reply(&error.to_string());

        prop_assert_eq!(render_node_error_reply(&error), plain_reply);
    }

    #[test]
    fn test_render_node_error_reply_property_kind_follows_the_variant(
        recipe in error_recipe_strategy(),
    ) {
        let expected_message = recipe.build().to_string();

        let reply = render_recipe(&recipe)?;

        let message = reply.get(ERROR_FIELD).and_then(Value::as_str);
        prop_assert_eq!(message, Some(expected_message.as_str()));
        let expected_kind = recipe.is_no_account().then_some(NO_ACCOUNT_KIND);
        prop_assert_eq!(read_kind(&reply), expected_kind);
        prop_assert!(is_defined_reply(&reply), "{}", reply);
        prop_assert_eq!(reply.get(SUCCESS_FIELD), None);
    }

    #[test]
    fn test_render_reply_property_errors_render_like_node_error_replies(
        recipe in error_recipe_strategy(),
    ) {
        let expected_reply = render_node_error_reply(&recipe.build());

        let reply_text = render_reply(&Err(recipe.build()));

        prop_assert_eq!(reply_text, expected_reply);
    }

    #[test]
    fn test_render_reply_property_a_success_carries_no_kind(
        success in arbitrary_json(),
    ) {
        let reply = parse_reply(&render_reply(&Ok(success.clone())))?;

        prop_assert_eq!(reply.get(ERROR_KIND_FIELD), None);
        prop_assert_eq!(reply.get(ERROR_FIELD), None);
        prop_assert_eq!(reply.get(SUCCESS_FIELD), Some(&success));
    }

    #[test]
    fn test_render_reply_property_every_outcome_is_one_defined_line(
        recipe in error_recipe_strategy(),
        success in arbitrary_json(),
        is_success in any::<bool>(),
    ) {
        let outcome = if is_success {
            Ok(success)
        } else {
            Err(recipe.build())
        };

        let reply_text = render_reply(&outcome);

        let reply = parse_reply(&reply_text)?;
        prop_assert!(is_one_line(&reply_text), "{}", reply_text);
        prop_assert!(is_defined_reply(&reply), "{}", reply);
        let has_kind = read_kind(&reply).is_some();
        prop_assert_eq!(has_kind, !is_success && recipe.is_no_account());
    }
}

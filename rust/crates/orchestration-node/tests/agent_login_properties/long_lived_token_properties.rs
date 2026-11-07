use orchestration_node::agent_credentials::{
    AgentCredential, AgentCredentialKind,
};
use orchestration_node::agent_login::{
    find_long_lived_token, hide_long_lived_tokens,
};
use proptest::prelude::*;

use crate::support::test_device::fail;
use crate::token_texts::{
    HIDDEN_TOKEN, TOKEN_PREFIX, any_hostile_token_text, any_long_secret_token,
    any_other_character, any_token, any_tokenless_text, expect_hidden_text,
    expect_tokens,
};

const MAXIMUM_TOKENS: usize = 5;
const LONG_SECRET_START: usize = "sk-ant-oat01-".len();

fn join_with_separators(tokens: &[String], separator: char) -> String {
    let mut text = String::new();
    for token in tokens {
        text.push_str(token);
        text.push(separator);
    }
    text
}

proptest! {
    #[test]
    fn test_find_long_lived_token_property_agrees_with_a_run_model(
        text in any_hostile_token_text(),
    ) {
        let expected = expect_tokens(&text).pop();

        prop_assert_eq!(find_long_lived_token(&text), expected);
    }

    #[test]
    fn test_find_long_lived_token_property_a_found_token_is_a_credential(
        text in any_hostile_token_text(),
    ) {
        let Some(token) = find_long_lived_token(&text) else {
            return Ok(());
        };

        let credential = AgentCredential::new(
            AgentCredentialKind::LongLivedToken,
            &token,
        )
        .map_err(fail)?;
        prop_assert!(text.contains(&token));
        prop_assert!(token.starts_with(TOKEN_PREFIX));
        prop_assert_eq!(credential.secret(), token.as_str());
    }

    #[test]
    fn test_find_long_lived_token_property_unicode_neighbours_are_ignored(
        before in any_tokenless_text(),
        token in any_token(),
        neighbour in any_other_character(),
        after in any_tokenless_text(),
    ) {
        let text = format!("{before}{neighbour}{token}{neighbour}{after}");

        prop_assert_eq!(find_long_lived_token(&text), Some(token));
    }

    #[test]
    fn test_hide_long_lived_tokens_property_agrees_with_a_run_model(
        text in any_hostile_token_text(),
    ) {
        let expected = expect_hidden_text(&text);

        prop_assert_eq!(hide_long_lived_tokens(&text), expected);
    }

    #[test]
    fn test_hide_long_lived_tokens_property_is_idempotent(
        text in any_hostile_token_text(),
    ) {
        let hidden_once = hide_long_lived_tokens(&text);

        let hidden_twice = hide_long_lived_tokens(&hidden_once);

        prop_assert_eq!(hidden_twice, hidden_once);
    }

    #[test]
    fn test_hide_long_lived_tokens_property_leaves_no_token_to_find(
        text in any_hostile_token_text(),
    ) {
        let hidden = hide_long_lived_tokens(&text);

        prop_assert_eq!(find_long_lived_token(&hidden), None);
    }

    #[test]
    fn test_hide_long_lived_tokens_property_no_secret_survives(
        tokens in proptest::collection::vec(
            any_long_secret_token(),
            1..MAXIMUM_TOKENS,
        ),
        separator in any_other_character(),
    ) {
        let text = join_with_separators(&tokens, separator);

        let hidden = hide_long_lived_tokens(&text);

        for token in &tokens {
            let secret = &token[LONG_SECRET_START..];
            prop_assert!(!hidden.contains(secret), "{hidden}");
        }
        let hidden_token = format!("{HIDDEN_TOKEN}{separator}");
        prop_assert_eq!(hidden, hidden_token.repeat(tokens.len()));
    }
}

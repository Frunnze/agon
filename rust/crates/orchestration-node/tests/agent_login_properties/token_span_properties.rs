use orchestration_node::agent_login::{
    find_long_lived_token, hide_long_lived_tokens,
};
use proptest::prelude::*;

use crate::token_texts::{
    HIDDEN_TOKEN, TOKEN_PREFIX, any_other_character, any_token,
    any_tokenless_text, is_token_character,
};

const MAXIMUM_TOKENS: usize = 5;
const SECRET_PART: &str = "[A-Za-z0-9_-]{1,40}";
const TOKEN_CHARACTERS: &str =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_";
const UNICODE_LOOKALIKES: [char; 6] =
    ['é', '٣', '\u{ff21}', '\u{ff11}', 'ß', '‐'];

fn any_token_character() -> impl Strategy<Value = char> {
    let characters: Vec<char> = TOKEN_CHARACTERS.chars().collect();
    proptest::sample::select(characters)
}

fn any_tokens() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::vec(any_token(), 1..MAXIMUM_TOKENS)
}

proptest! {
    #[test]
    fn test_find_token_spans_property_separated_tokens_are_each_hidden(
        tokens in any_tokens(),
        separator in any_other_character(),
    ) {
        let text = tokens.join(&separator.to_string());

        let hidden = hide_long_lived_tokens(&text);

        let hidden_marks = vec![HIDDEN_TOKEN; tokens.len()];
        prop_assert_eq!(hidden, hidden_marks.join(&separator.to_string()));
        prop_assert_eq!(find_long_lived_token(&text), tokens.last().cloned());
    }

    #[test]
    fn test_find_token_spans_property_glued_tokens_are_hidden_together(
        tokens in any_tokens(),
    ) {
        let text = tokens.concat();

        let hidden = hide_long_lived_tokens(&text);

        prop_assert_eq!(hidden, HIDDEN_TOKEN);
        prop_assert_eq!(find_long_lived_token(&text), Some(text));
    }

    #[test]
    fn test_find_token_spans_property_a_failed_prefix_keeps_searching(
        broken_tail in "[A-Za-z_]?[ .:]",
        token in any_token(),
    ) {
        let text = format!("{TOKEN_PREFIX}{broken_tail}{token}");

        prop_assert_eq!(find_long_lived_token(&text), Some(token));
    }

    #[test]
    fn test_measure_token_property_a_version_needs_a_digit(
        before in any_tokenless_text(),
        secret in SECRET_PART,
    ) {
        let text = format!("{before}{TOKEN_PREFIX}-{secret}");

        prop_assert_eq!(find_long_lived_token(&text), None);
        prop_assert_eq!(hide_long_lived_tokens(&text), text);
    }

    #[test]
    fn test_measure_token_property_any_digit_count_is_a_version(
        version in "[0-9]{1,12}",
        secret in SECRET_PART,
        after in any_tokenless_text(),
    ) {
        let token = format!("{TOKEN_PREFIX}{version}-{secret}");
        let text = format!("{token}{after}");

        prop_assert_eq!(find_long_lived_token(&text), Some(token));
    }

    #[test]
    fn test_measure_token_property_a_version_needs_its_dash(
        version in "[0-9]{1,3}",
        joiner in "[A-Za-z_.: ]",
        secret in SECRET_PART,
    ) {
        let text = format!("{TOKEN_PREFIX}{version}{joiner}{secret}");

        prop_assert_eq!(find_long_lived_token(&text), None);
    }

    #[test]
    fn test_measure_token_property_the_secret_ends_at_another_character(
        token in any_token(),
        stopper in any_other_character(),
        rest in SECRET_PART,
    ) {
        let text = format!("{token}{stopper}{rest}");

        prop_assert_eq!(find_long_lived_token(&text), Some(token));
    }

    #[test]
    fn test_is_token_character_property_token_characters_extend_it(
        token in any_token(),
        extension in proptest::collection::vec(any_token_character(), 1..8),
    ) {
        let extension: String = extension.into_iter().collect();
        let extended = format!("{token}{extension}");

        prop_assert_eq!(find_long_lived_token(&extended), Some(extended));
    }

    #[test]
    fn test_is_token_character_property_other_characters_end_it(
        token in any_token(),
        stopper in any::<char>(),
        rest in SECRET_PART,
    ) {
        prop_assume!(!is_token_character(stopper));
        let text = format!("{token}{stopper}{rest}");

        prop_assert_eq!(find_long_lived_token(&text), Some(token));
    }

    #[test]
    fn test_is_token_character_property_unicode_lookalikes_end_it(
        token in any_token(),
        lookalike in proptest::sample::select(UNICODE_LOOKALIKES.to_vec()),
        rest in SECRET_PART,
    ) {
        let text = format!("{token}{lookalike}{rest}");

        let hidden = hide_long_lived_tokens(&text);

        prop_assert_eq!(find_long_lived_token(&text), Some(token));
        prop_assert_eq!(hidden, format!("{HIDDEN_TOKEN}{lookalike}{rest}"));
    }
}

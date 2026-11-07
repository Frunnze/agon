use orchestration_node::agent_credentials::{
    API_KEY_VARIABLE, AgentCredential, AgentCredentialKind,
    LONG_LIVED_TOKEN_VARIABLE,
};
use proptest::prelude::*;

use crate::secret_rules::{
    BROKEN_SECRET_PROBLEM, any_control_character, any_credential,
    any_hostile_text, any_kind, any_valid_secret, any_white_space,
    any_white_space_padding, expect_secret_rules, is_breaking_character,
    is_unicode_white_space,
};
use crate::support::test_device::fail;

const LONG_RANDOM_SECRET: &str = "[A-Za-z0-9]{16,40}";

fn describe_new(
    kind: AgentCredentialKind,
    text: &str,
) -> Result<String, String> {
    let credential = AgentCredential::new(kind, text);
    credential
        .map(|kept| kept.secret().to_owned())
        .map_err(|problem| problem.to_string())
}

fn is_shell_variable_character(character: char) -> bool {
    character.is_ascii_uppercase()
        || character.is_ascii_digit()
        || character == '_'
}

fn is_shell_variable_name(name: &str) -> bool {
    let starts_with_a_digit = name
        .chars()
        .next()
        .is_none_or(|first| first.is_ascii_digit());
    let has_only_name_characters =
        name.chars().all(is_shell_variable_character);
    !starts_with_a_digit && has_only_name_characters
}

proptest! {
    #[test]
    fn test_agent_credential_new_property_follows_the_reference_rules(
        kind in any_kind(),
        text in any_hostile_text(),
    ) {
        prop_assert_eq!(describe_new(kind, &text), expect_secret_rules(&text));
    }

    #[test]
    fn test_agent_credential_new_property_unicode_padding_is_trimmed(
        kind in any_kind(),
        secret in any_valid_secret(),
        padding_before in any_white_space_padding(),
        padding_after in any_white_space_padding(),
    ) {
        let padded = format!("{padding_before}{secret}{padding_after}");

        prop_assert_eq!(describe_new(kind, &padded), Ok(secret));
    }

    #[test]
    fn test_agent_credential_new_property_inner_unicode_space_is_refused(
        kind in any_kind(),
        start in any_valid_secret(),
        breaker in any_white_space(),
        end in any_valid_secret(),
    ) {
        let secret = format!("{start}{breaker}{end}");

        prop_assert_eq!(
            describe_new(kind, &secret),
            Err(BROKEN_SECRET_PROBLEM.to_owned())
        );
    }

    #[test]
    fn test_agent_credential_new_property_a_control_anywhere_is_refused(
        kind in any_kind(),
        secret in any_valid_secret(),
        control in any_control_character(),
        position in any::<proptest::sample::Index>(),
    ) {
        prop_assume!(!is_unicode_white_space(control));
        let characters: Vec<char> = secret.chars().collect();
        let split_at = position.index(characters.len() + 1);
        let before: String = characters[..split_at].iter().collect();
        let after: String = characters[split_at..].iter().collect();
        let broken = format!("{before}{control}{after}");

        prop_assert_eq!(
            describe_new(kind, &broken),
            Err(BROKEN_SECRET_PROBLEM.to_owned())
        );
    }

    #[test]
    fn test_agent_credential_new_property_is_idempotent(
        kind in any_kind(),
        text in any_hostile_text(),
    ) {
        let Ok(first) = AgentCredential::new(kind, &text) else {
            return Ok(());
        };

        let second =
            AgentCredential::new(kind, first.secret()).map_err(fail)?;

        prop_assert_eq!(second, first);
    }

    #[test]
    fn test_agent_credential_kind_property_keeps_the_given_kind(
        kind in any_kind(),
        secret in any_valid_secret(),
    ) {
        let credential = AgentCredential::new(kind, &secret).map_err(fail)?;

        prop_assert_eq!(credential.kind(), kind);
    }

    #[test]
    fn test_agent_credential_kind_property_does_not_follow_the_padding(
        kind in any_kind(),
        secret in any_valid_secret(),
        padding in any_white_space_padding(),
    ) {
        let padded = format!("{padding}{secret}{padding}");

        let plain = AgentCredential::new(kind, &secret).map_err(fail)?;
        let trimmed = AgentCredential::new(kind, &padded).map_err(fail)?;

        prop_assert_eq!(trimmed.kind(), plain.kind());
        prop_assert_eq!(trimmed, plain);
    }

    #[test]
    fn test_agent_credential_kind_property_tells_equal_secrets_apart(
        secret in any_valid_secret(),
    ) {
        let token = AgentCredential::new(
            AgentCredentialKind::LongLivedToken,
            &secret,
        )
        .map_err(fail)?;
        let api_key =
            AgentCredential::new(AgentCredentialKind::ApiKey, &secret)
                .map_err(fail)?;

        prop_assert_ne!(token.kind(), api_key.kind());
        prop_assert_ne!(token, api_key);
    }

    #[test]
    fn test_agent_credential_secret_property_has_no_breaking_characters(
        credential in any_credential(),
    ) {
        let secret = credential.secret();

        prop_assert!(!secret.is_empty());
        prop_assert!(!secret.chars().any(is_breaking_character));
    }

    #[test]
    fn test_agent_credential_secret_property_is_found_inside_the_input(
        kind in any_kind(),
        text in any_hostile_text(),
    ) {
        let Ok(credential) = AgentCredential::new(kind, &text) else {
            return Ok(());
        };

        prop_assert!(text.contains(credential.secret()));
        prop_assert!(credential.secret().len() <= text.len());
    }

    #[test]
    fn test_agent_credential_secret_property_keeps_every_inner_character(
        kind in any_kind(),
        secret in any_valid_secret(),
    ) {
        let credential = AgentCredential::new(kind, &secret).map_err(fail)?;

        prop_assert_eq!(credential.secret(), secret.as_str());
    }

    #[test]
    fn test_agent_credential_environment_variable_property_follows_the_kind(
        credential in any_credential(),
    ) {
        let expected = match credential.kind() {
            AgentCredentialKind::LongLivedToken => LONG_LIVED_TOKEN_VARIABLE,
            AgentCredentialKind::ApiKey => API_KEY_VARIABLE,
        };

        prop_assert_eq!(credential.environment_variable(), expected);
    }

    #[test]
    fn test_agent_credential_environment_variable_property_ignores_secrets(
        kind in any_kind(),
        first_secret in any_valid_secret(),
        second_secret in any_valid_secret(),
    ) {
        let first = AgentCredential::new(kind, &first_secret).map_err(fail)?;
        let second =
            AgentCredential::new(kind, &second_secret).map_err(fail)?;

        prop_assert_eq!(
            first.environment_variable(),
            second.environment_variable()
        );
    }

    #[test]
    fn test_agent_credential_environment_variable_property_is_a_shell_name(
        credential in any_credential(),
    ) {
        let variable = credential.environment_variable();

        prop_assert!(is_shell_variable_name(variable), "{variable}");
    }

    #[test]
    fn test_agent_credential_fmt_property_is_the_same_for_any_secret(
        kind in any_kind(),
        first_secret in any_valid_secret(),
        second_secret in any_valid_secret(),
    ) {
        let first = AgentCredential::new(kind, &first_secret).map_err(fail)?;
        let second =
            AgentCredential::new(kind, &second_secret).map_err(fail)?;

        prop_assert_eq!(format!("{first:?}"), format!("{second:?}"));
        prop_assert_eq!(format!("{first:#?}"), format!("{second:#?}"));
    }

    #[test]
    fn test_agent_credential_fmt_property_names_the_kind(
        credential in any_credential(),
    ) {
        let shown = format!("{credential:?}");
        let kind_name = format!("{:?}", credential.kind());

        prop_assert!(shown.contains(&kind_name), "{shown}");
    }

    #[test]
    fn test_agent_credential_fmt_property_hides_the_secret_when_nested(
        kind in any_kind(),
        secret in LONG_RANDOM_SECRET,
    ) {
        let credential = AgentCredential::new(kind, &secret).map_err(fail)?;
        let kept = Some(vec![credential.clone()]);

        let shown = format!("{kept:?} {kept:#?}");

        prop_assert!(!shown.contains(credential.secret()), "{shown}");
    }
}

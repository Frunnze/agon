use orchestration_hub::process_supervisor::ProcessExit;
use orchestration_node::agent_credentials::{
    AgentCredential, AgentCredentialKind,
};
use orchestration_node::agent_login::{
    ClaudeLogin, LoginOutcome, decide_login_outcome, find_long_lived_token,
    hide_long_lived_tokens, interpret_login_answer,
};
use orchestration_node::runner_settings::AgentPlace;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::test_device::fail;

fn any_token() -> impl Strategy<Value = String> {
    "sk-ant-oat0[1-9]-[A-Za-z0-9_-]{20,100}"
}

fn any_surrounding_text() -> impl Strategy<Value = String> {
    "([ \n:>✓().!]|[A-Za-z ]{0,20}[ \n:>]){0,4}"
}

fn any_exit() -> impl Strategy<Value = ProcessExit> {
    prop_oneof![
        Just(ProcessExit::Succeeded),
        (1_u32..255).prop_map(ProcessExit::FailedWithCode),
        "[A-Z][a-z]{2,8}".prop_map(ProcessExit::KilledBySignal),
    ]
}

fn any_unsuccessful_exit() -> impl Strategy<Value = ProcessExit> {
    prop_oneof![
        (1_u32..255).prop_map(ProcessExit::FailedWithCode),
        "[A-Z][a-z]{2,8}".prop_map(ProcessExit::KilledBySignal),
    ]
}

proptest! {
    #[test]
    fn test_find_long_lived_token_property_finds_the_printed_token(
        before in any_surrounding_text(),
        token in any_token(),
        after in any_surrounding_text(),
    ) {
        let output = format!("{before}{token}\n{after}");

        prop_assert_eq!(find_long_lived_token(&output), Some(token));
    }

    #[test]
    fn test_find_long_lived_token_property_takes_the_last_token(
        first in any_token(),
        last in any_token(),
        between in any_surrounding_text(),
    ) {
        let output = format!("{first}\n{between}\n{last}");

        prop_assert_eq!(find_long_lived_token(&output), Some(last));
    }

    #[test]
    fn test_find_long_lived_token_property_other_text_has_no_token(
        output in "[^k]{0,200}",
    ) {
        prop_assert_eq!(find_long_lived_token(&output), None);
    }

    #[test]
    fn test_find_long_lived_token_property_a_bare_prefix_is_no_token(
        before in any_surrounding_text(),
        version in "[0-9]{0,2}",
        after in "[ \n.]{0,3}",
    ) {
        let output = format!("{before}sk-ant-oat{version}-{after}");

        prop_assert_eq!(find_long_lived_token(&output), None);
    }

    #[test]
    fn test_hide_long_lived_tokens_property_hidden_text_has_no_token(
        before in any_surrounding_text(),
        token in any_token(),
        after in any_surrounding_text(),
    ) {
        let line = format!("{before}{token} {after}");

        let hidden = hide_long_lived_tokens(&line);

        prop_assert!(!hidden.contains(&token));
        prop_assert_eq!(find_long_lived_token(&hidden), None);
        prop_assert!(hidden.starts_with(&before));
        let expected_end = format!(" {after}");
        prop_assert!(hidden.ends_with(&expected_end));
    }

    #[test]
    fn test_hide_long_lived_tokens_property_text_without_tokens_is_kept(
        line in "[^k]{0,120}",
    ) {
        prop_assert_eq!(hide_long_lived_tokens(&line), line);
    }

    #[test]
    fn test_decide_login_outcome_property_a_seen_token_connects(
        exit in any_exit(),
        token in any_token(),
    ) {
        let outcome =
            decide_login_outcome(AgentPlace::Container, &exit, Some(&token));

        let expected = AgentCredential::new(
            AgentCredentialKind::LongLivedToken,
            &token,
        )
        .map_err(fail)?;
        prop_assert_eq!(outcome, LoginOutcome::Connected(expected));
    }

    #[test]
    fn test_decide_login_outcome_property_no_token_is_a_failure(
        exit in any_exit(),
    ) {
        let outcome = decide_login_outcome(AgentPlace::Container, &exit, None);

        prop_assert!(matches!(outcome, LoginOutcome::Failed(_)));
    }

    #[test]
    fn test_decide_login_outcome_property_a_clean_local_exit_logs_in(
        token in proptest::option::of(any_token()),
    ) {
        let outcome = decide_login_outcome(
            AgentPlace::LocalProcess,
            &ProcessExit::Succeeded,
            token.as_deref(),
        );

        prop_assert_eq!(outcome, LoginOutcome::LoggedIn);
    }

    #[test]
    fn test_decide_login_outcome_property_a_failed_local_exit_says_how(
        exit in any_unsuccessful_exit(),
    ) {
        let outcome =
            decide_login_outcome(AgentPlace::LocalProcess, &exit, None);

        let LoginOutcome::Failed(problem) = outcome else {
            return Err(TestCaseError::fail("the failed login logged in"));
        };
        if let ProcessExit::FailedWithCode(code) = exit {
            prop_assert!(problem.contains(&code.to_string()));
        }
    }

    #[test]
    fn test_interpret_login_answer_property_reads_the_logged_in_field(
        logged_in in any::<bool>(),
        method in "[a-z._]{1,12}",
        extra in proptest::collection::btree_map(
            "[a-z]{1,8}",
            "[a-z0-9 ]{0,12}",
            0..4,
        ),
    ) {
        let mut answer = json!({
            "loggedIn": logged_in,
            "authMethod": method,
        });
        for (name, value) in extra {
            answer[name] = Value::String(value);
        }

        let login = interpret_login_answer(&format!("{answer}\n"))
            .map_err(fail)?;

        let expected = if logged_in {
            ClaudeLogin::LoggedIn
        } else {
            ClaudeLogin::NotLoggedIn
        };
        prop_assert_eq!(login, expected);
    }

    #[test]
    fn test_interpret_login_answer_property_other_answers_are_errors(
        answer in "\\PC{0,80}",
    ) {
        let is_status = serde_json::from_str::<Value>(answer.trim())
            .ok()
            .and_then(|value| value.get("loggedIn").cloned())
            .is_some_and(|field| field.is_boolean());
        prop_assume!(!is_status);

        prop_assert!(interpret_login_answer(&answer).is_err());
    }
}

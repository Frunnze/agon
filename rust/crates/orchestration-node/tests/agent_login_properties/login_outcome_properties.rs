use orchestration_core::agent_place::AgentPlace;
use orchestration_hub::process_supervisor::ProcessExit;
use orchestration_node::agent_credentials::{
    AgentCredential, AgentCredentialKind,
};
use orchestration_node::agent_login::{LoginOutcome, decide_login_outcome};
use proptest::prelude::*;

use crate::secret_rules::{
    any_hostile_text, any_white_space_padding, expect_secret_rules,
};
use crate::support::test_device::fail;
use crate::token_texts::any_token;

fn any_place() -> impl Strategy<Value = AgentPlace> {
    prop_oneof![Just(AgentPlace::Container), Just(AgentPlace::LocalProcess)]
}

fn any_signal() -> impl Strategy<Value = ProcessExit> {
    "[A-Z]{3,8}".prop_map(ProcessExit::KilledBySignal)
}

fn any_failure_code() -> impl Strategy<Value = ProcessExit> {
    (1_u32..=u32::MAX).prop_map(ProcessExit::FailedWithCode)
}

fn any_exit() -> impl Strategy<Value = ProcessExit> {
    prop_oneof![
        Just(ProcessExit::Succeeded),
        any_failure_code(),
        any_signal()
    ]
}

fn any_unsuccessful_exit() -> impl Strategy<Value = ProcessExit> {
    prop_oneof![any_failure_code(), any_signal()]
}

fn describe_tokenless_failure(
    place: AgentPlace,
    exit: &ProcessExit,
) -> Result<String, TestCaseError> {
    let outcome = decide_login_outcome(place, exit, None);
    let LoginOutcome::Failed(problem) = outcome else {
        return Err(TestCaseError::fail(format!(
            "not a failure: {outcome:?}"
        )));
    };
    Ok(problem)
}

fn build_token_credential(
    secret: &str,
) -> Result<AgentCredential, TestCaseError> {
    AgentCredential::new(AgentCredentialKind::LongLivedToken, secret)
        .map_err(fail)
}

fn are_both_signals(first: &ProcessExit, second: &ProcessExit) -> bool {
    let is_first_a_signal = matches!(first, ProcessExit::KilledBySignal(_));
    let is_second_a_signal = matches!(second, ProcessExit::KilledBySignal(_));
    is_first_a_signal && is_second_a_signal
}

proptest! {
    #[test]
    fn test_decide_login_outcome_property_a_local_login_never_connects(
        exit in any_exit(),
        token in proptest::option::of(any_token()),
    ) {
        let outcome = decide_login_outcome(
            AgentPlace::LocalProcess,
            &exit,
            token.as_deref(),
        );

        prop_assert!(!matches!(outcome, LoginOutcome::Connected(_)));
    }

    #[test]
    fn test_decide_login_outcome_property_a_container_never_just_logs_in(
        exit in any_exit(),
        token in proptest::option::of(any_token()),
    ) {
        let seen_token = token.as_deref();

        let outcome =
            decide_login_outcome(AgentPlace::Container, &exit, seen_token);

        prop_assert_ne!(outcome, LoginOutcome::LoggedIn);
    }

    #[test]
    fn test_decide_login_outcome_property_a_failure_never_names_the_token(
        place in any_place(),
        exit in any_unsuccessful_exit(),
        token in "[A-Za-z0-9]{12,30}",
        breaker in " |\n|\t",
    ) {
        let seen = format!("{token}{breaker}{token}");

        let outcome = decide_login_outcome(place, &exit, Some(&seen));

        let LoginOutcome::Failed(problem) = outcome else {
            return Err(TestCaseError::fail("a broken token was accepted"));
        };
        prop_assert!(!problem.contains(&token), "{problem}");
        prop_assert!(!problem.is_empty());
    }

    #[test]
    fn test_connect_with_property_follows_the_secret_rules(
        exit in any_exit(),
        seen in any_hostile_text(),
    ) {
        let outcome =
            decide_login_outcome(AgentPlace::Container, &exit, Some(&seen));

        let expected = match expect_secret_rules(&seen) {
            Ok(secret) => {
                LoginOutcome::Connected(build_token_credential(&secret)?)
            }
            Err(problem) => LoginOutcome::Failed(problem),
        };
        prop_assert_eq!(outcome, expected);
    }

    #[test]
    fn test_connect_with_property_keeps_a_long_lived_token(
        exit in any_exit(),
        token in any_token(),
    ) {
        let outcome =
            decide_login_outcome(AgentPlace::Container, &exit, Some(&token));

        let LoginOutcome::Connected(credential) = outcome else {
            return Err(TestCaseError::fail("the token was not connected"));
        };
        let kind = credential.kind();
        prop_assert_eq!(kind, AgentCredentialKind::LongLivedToken);
        prop_assert_eq!(credential.secret(), token.as_str());
    }

    #[test]
    fn test_connect_with_property_padding_around_the_token_is_dropped(
        exit in any_exit(),
        token in any_token(),
        padding in any_white_space_padding(),
    ) {
        let padded = format!("{padding}{token}{padding}");

        let padded_outcome =
            decide_login_outcome(AgentPlace::Container, &exit, Some(&padded));
        let plain_outcome =
            decide_login_outcome(AgentPlace::Container, &exit, Some(&token));

        prop_assert_eq!(padded_outcome, plain_outcome);
    }

    #[test]
    fn test_describe_tokenless_exit_property_names_the_exit_code(
        place in any_place(),
        code in 1_u32..=u32::MAX,
    ) {
        let exit = ProcessExit::FailedWithCode(code);

        let problem = describe_tokenless_failure(place, &exit)?;

        prop_assert!(problem.contains(&code.to_string()), "{problem}");
    }

    #[test]
    fn test_describe_tokenless_exit_property_tells_exits_apart(
        first in any_exit(),
        second in any_exit(),
    ) {
        let place = AgentPlace::Container;

        let first_problem = describe_tokenless_failure(place, &first)?;
        let second_problem = describe_tokenless_failure(place, &second)?;

        if first == second {
            prop_assert_eq!(first_problem, second_problem);
        } else if !are_both_signals(&first, &second) {
            prop_assert_ne!(first_problem, second_problem);
        }
    }

    #[test]
    fn test_describe_tokenless_exit_property_is_the_same_in_both_places(
        exit in any_unsuccessful_exit(),
    ) {
        let in_container =
            describe_tokenless_failure(AgentPlace::Container, &exit)?;
        let on_this_computer =
            describe_tokenless_failure(AgentPlace::LocalProcess, &exit)?;

        prop_assert_eq!(in_container, on_this_computer);
    }
}

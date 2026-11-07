use orchestration_core::agent_place::AgentPlace;
use orchestration_hub::process_supervisor::ProcessExit;
use orchestration_node::agent_login::{LoginOutcome, decide_login_outcome};
use proptest::prelude::*;

use crate::login_records::STOPPED_PROBLEM;

fn any_place() -> impl Strategy<Value = AgentPlace> {
    prop_oneof![Just(AgentPlace::Container), Just(AgentPlace::LocalProcess)]
}

fn any_signal_description() -> impl Strategy<Value = String> {
    prop_oneof![
        "[0-9]{1,2}",
        "[A-Z][a-z]{2,12}(: [0-9]{1,2})?",
        "[A-Za-z][A-Za-z :0-9]{0,30}",
    ]
}

fn describe_signal_failure(
    place: AgentPlace,
    signal: &str,
) -> Result<String, TestCaseError> {
    let exit = ProcessExit::KilledBySignal(signal.to_owned());
    let outcome = decide_login_outcome(place, &exit, None);
    let LoginOutcome::Failed(problem) = outcome else {
        return Err(TestCaseError::fail(format!(
            "not a failure: {outcome:?}"
        )));
    };
    Ok(problem)
}

proptest! {
    #[test]
    fn test_describe_tokenless_exit_property_a_signal_is_never_a_stop(
        place in any_place(),
        signal in any_signal_description(),
    ) {
        let problem = describe_signal_failure(place, &signal)?;

        prop_assert_ne!(problem, STOPPED_PROBLEM);
    }

    #[test]
    fn test_describe_tokenless_exit_property_names_the_signal(
        place in any_place(),
        signal in any_signal_description(),
    ) {
        let problem = describe_signal_failure(place, &signal)?;

        prop_assert!(problem.contains(&signal), "{problem}");
    }

    #[test]
    fn test_describe_tokenless_exit_property_tells_signals_apart(
        place in any_place(),
        first_signal in any_signal_description(),
        second_signal in any_signal_description(),
    ) {
        let first_problem = describe_signal_failure(place, &first_signal)?;
        let second_problem = describe_signal_failure(place, &second_signal)?;

        prop_assert_eq!(
            first_problem == second_problem,
            first_signal == second_signal
        );
    }
}

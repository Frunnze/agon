use proptest::prelude::*;
use serde_json::Value;

use crate::login_records::{
    CLAUDE_LOGIN_FIELD, CREDENTIAL_KIND_FIELD, FAILED_STATE,
    LOGIN_RUNNER_CASES, NOT_LOGGED_IN, STOPPED_PROBLEM, TYPED_CODE_FILE_NAME,
    any_crash_signal, any_login_code, any_place, ask_for_a_crash, read_status,
    start_nodes,
};
use crate::support::test_device::fail;

const SIGNAL_WORD: &str = "signal";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LOGIN_RUNNER_CASES))]

    #[test]
    fn test_follow_property_a_crash_fails_with_its_signal(
        place in any_place(),
        signal in any_crash_signal(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        ask_for_a_crash(&nodes, signal)?;

        let ending =
            nodes.log_in_through_the_terminal(place, &code).map_err(fail)?;

        prop_assert_eq!(&ending["state"], FAILED_STATE, "{}", ending);
        let problem = ending["problem"].as_str().unwrap_or_default();
        prop_assert_ne!(problem, STOPPED_PROBLEM);
        prop_assert!(problem.contains(SIGNAL_WORD), "{problem}");
    }

    #[test]
    fn test_follow_property_a_crash_signs_nothing_in(
        place in any_place(),
        signal in any_crash_signal(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        ask_for_a_crash(&nodes, signal)?;

        nodes.log_in_through_the_terminal(place, &code).map_err(fail)?;

        let status = read_status(&nodes)?;
        prop_assert_eq!(&status[CLAUDE_LOGIN_FIELD], NOT_LOGGED_IN);
        prop_assert_eq!(&status[CREDENTIAL_KIND_FIELD], &Value::Null);
        let typed_path = nodes.records.path().join(TYPED_CODE_FILE_NAME);
        prop_assert!(!typed_path.exists());
    }
}

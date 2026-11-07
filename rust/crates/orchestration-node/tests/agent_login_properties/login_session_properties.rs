use std::fs;
use std::thread;
use std::time::Duration;

use proptest::prelude::*;
use serde_json::Value;

use crate::login_steps::{
    CONTAINER_PLACE, CREDENTIAL_KIND_FIELD, ENTER_KEY, LOCAL_PLACE,
    LOGIN_CASES, LOGIN_PROMPT, RUNNING_STATE, TOKEN_START,
    TYPED_CODE_FILE_NAME, any_login_code, any_place, expected_command,
    fail_container_login, finish_login, read_login, read_status_field,
    start_login, start_login_to_prompt, start_nodes,
    start_nodes_without_claude, stop_login, type_keys,
};
use crate::support::test_device::fail;

const SETTLING_PAUSE: Duration = Duration::from_millis(400);
const LONG_LIVED_TOKEN_NAME: &str = "long_lived_token";
const MAXIMUM_STOPS: usize = 3;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LOGIN_CASES))]

    #[test]
    fn test_login_session_start_property_a_new_login_runs_its_command(
        place in any_place(),
    ) {
        let nodes = start_nodes()?;

        start_login(&nodes, place).map_err(fail)?;

        let shown = read_login(&nodes).map_err(fail)?;
        prop_assert_eq!(&shown["place"], place);
        prop_assert_eq!(&shown["command"], expected_command(place));
        prop_assert_eq!(&shown["state"], RUNNING_STATE);
        prop_assert_eq!(&shown["problem"], &Value::Null);
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_login_session_start_property_without_claude_nothing_opens(
        place in any_place(),
    ) {
        let nodes = start_nodes_without_claude()?;

        let started = start_login(&nodes, place);

        prop_assert!(started.is_err(), "{started:?}");
        prop_assert_eq!(read_login(&nodes).map_err(fail)?, Value::Null);
    }

    #[test]
    fn test_login_session_start_property_the_program_output_is_shown(
        place in any_place(),
    ) {
        let nodes = start_nodes()?;

        start_login_to_prompt(&nodes, place)?;

        let shown = read_login(&nodes).map_err(fail)?;
        prop_assert!(shown["lines"].to_string().contains(LOGIN_PROMPT));
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_login_session_has_ended_property_a_finished_login_frees_it(
        place in any_place(),
        code in any_login_code(),
        next_place in any_place(),
    ) {
        let nodes = start_nodes()?;
        finish_login(&nodes, place, &code)?;

        start_login(&nodes, next_place).map_err(fail)?;

        let shown = read_login(&nodes).map_err(fail)?;
        prop_assert_eq!(&shown["place"], next_place);
        prop_assert_eq!(&shown["state"], RUNNING_STATE);
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_login_session_has_ended_property_a_failed_login_frees_it(
        next_place in any_place(),
    ) {
        let nodes = start_nodes()?;
        fail_container_login(&nodes)?;

        start_login(&nodes, next_place).map_err(fail)?;

        let shown = read_login(&nodes).map_err(fail)?;
        prop_assert_eq!(&shown["state"], RUNNING_STATE);
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_login_session_has_ended_property_waiting_keys_keep_it_open(
        place in any_place(),
        unfinished_code in any_login_code(),
        next_place in any_place(),
    ) {
        let nodes = start_nodes()?;
        start_login_to_prompt(&nodes, place)?;
        type_keys(&nodes, &unfinished_code).map_err(fail)?;
        thread::sleep(SETTLING_PAUSE);

        let second = start_login(&nodes, next_place);

        prop_assert!(second.is_err(), "{second:?}");
        prop_assert_eq!(&read_login(&nodes).map_err(fail)?["place"], place);
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_login_session_view_property_never_shows_the_token(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let ending = finish_login(&nodes, CONTAINER_PLACE, &code)?;

        let shown_lines = ending["lines"].to_string();
        let token = format!("{TOKEN_START}{code}");
        prop_assert!(!shown_lines.contains(&token), "{}", shown_lines);
        prop_assert!(!shown_lines.contains("sk-ant-oat"), "{shown_lines}");
    }

    #[test]
    fn test_login_session_view_property_only_a_failure_has_a_problem(
        place in any_place(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        let finished = finish_login(&nodes, place, &code)?;

        let failed = fail_container_login(&nodes)?;

        prop_assert_eq!(&finished["problem"], &Value::Null);
        let problem = failed["problem"].as_str().unwrap_or_default();
        prop_assert!(!problem.is_empty(), "{failed}");
    }

    #[test]
    fn test_login_session_view_property_place_and_command_stay_fixed(
        place in any_place(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        start_login(&nodes, place).map_err(fail)?;
        let first = read_login(&nodes).map_err(fail)?;
        nodes.wait_for_login_text(LOGIN_PROMPT).map_err(fail)?;
        type_keys(&nodes, &format!("{code}{ENTER_KEY}")).map_err(fail)?;

        let last = nodes.wait_for_login_end().map_err(fail)?;

        prop_assert_eq!(&first["place"], &last["place"]);
        prop_assert_eq!(&first["command"], &last["command"]);
    }

    #[test]
    fn test_login_session_type_keys_property_the_code_reaches_the_program(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        finish_login(&nodes, LOCAL_PLACE, &code)?;

        let typed_path = nodes.records.path().join(TYPED_CODE_FILE_NAME);
        let typed = fs::read_to_string(typed_path).map_err(fail)?;
        prop_assert_eq!(typed.trim_end(), code.as_str());
    }

    #[test]
    fn test_login_session_type_keys_property_split_keys_arrive_whole(
        code in any_login_code(),
        split_at in any::<proptest::sample::Index>(),
    ) {
        let nodes = start_nodes()?;
        let (first_part, second_part) =
            code.split_at(split_at.index(code.len() + 1));
        start_login_to_prompt(&nodes, LOCAL_PLACE)?;

        type_keys(&nodes, first_part).map_err(fail)?;
        type_keys(&nodes, &format!("{second_part}{ENTER_KEY}"))
            .map_err(fail)?;
        nodes.wait_for_login_end().map_err(fail)?;

        let typed_path = nodes.records.path().join(TYPED_CODE_FILE_NAME);
        let typed = fs::read_to_string(typed_path).map_err(fail)?;
        prop_assert_eq!(typed.trim_end(), code.as_str());
    }

    #[test]
    fn test_login_session_type_keys_property_keys_wait_for_the_enter_key(
        unfinished_code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        start_login_to_prompt(&nodes, LOCAL_PLACE)?;

        type_keys(&nodes, &unfinished_code).map_err(fail)?;
        thread::sleep(SETTLING_PAUSE);

        let typed_path = nodes.records.path().join(TYPED_CODE_FILE_NAME);
        prop_assert!(!typed_path.exists());
        let shown = read_login(&nodes).map_err(fail)?;
        prop_assert_eq!(&shown["state"], RUNNING_STATE);
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_login_session_stop_property_a_stopped_login_signs_nothing_in(
        place in any_place(),
        unfinished_code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        start_login_to_prompt(&nodes, place)?;
        type_keys(&nodes, &unfinished_code).map_err(fail)?;

        stop_login(&nodes).map_err(fail)?;
        thread::sleep(SETTLING_PAUSE);

        let typed_path = nodes.records.path().join(TYPED_CODE_FILE_NAME);
        prop_assert!(!typed_path.exists());
        prop_assert_eq!(read_login(&nodes).map_err(fail)?, Value::Null);
        let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
        prop_assert_eq!(credential, Value::Null);
    }

    #[test]
    fn test_login_session_stop_property_an_ended_login_keeps_its_result(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        finish_login(&nodes, CONTAINER_PLACE, &code)?;

        stop_login(&nodes).map_err(fail)?;

        let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
        prop_assert_eq!(credential, LONG_LIVED_TOKEN_NAME);
    }

    #[test]
    fn test_login_session_stop_property_stopping_again_is_harmless(
        place in any_place(),
        stops in 1..=MAXIMUM_STOPS,
    ) {
        let nodes = start_nodes()?;
        start_login_to_prompt(&nodes, place)?;

        for _ in 0..stops {
            prop_assert_eq!(stop_login(&nodes).map_err(fail)?, Value::Null);
        }

        prop_assert_eq!(read_login(&nodes).map_err(fail)?, Value::Null);
    }
}

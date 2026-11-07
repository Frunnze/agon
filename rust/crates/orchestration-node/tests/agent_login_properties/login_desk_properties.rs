use proptest::prelude::*;
use serde_json::Value;

use crate::desk_model::{
    ModelLogin, any_desk_actions, play_against_the_model,
};
use crate::login_steps::{
    CLAUDE_LOGIN_FIELD, CONTAINER_PLACE, CREDENTIAL_KIND_FIELD, ENTER_KEY,
    LOCAL_PLACE, LOGIN_CASES, RUNNING_STATE, any_login_code, any_place,
    fail_container_login, finish_login, read_login, read_status_field,
    start_login, start_login_to_prompt, start_nodes, stop_login, type_keys,
};
use crate::support::test_device::fail;

const NO_LOGIN_PROBLEM: &str = "no Claude Code login is open";
const OPEN_LOGIN_PROBLEM: &str = "a Claude Code login is already open";
const LONG_LIVED_TOKEN_NAME: &str = "long_lived_token";
const NOT_LOGGED_IN_NAME: &str = "not_logged_in";
const MODEL_CASES: u32 = 3;
const MAXIMUM_REPEATS: usize = 3;

fn typed_line(code: &str) -> String {
    format!("{code}{ENTER_KEY}")
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LOGIN_CASES))]

    #[test]
    fn test_agent_login_desk_open_property_a_running_login_refuses_another(
        first_place in any_place(),
        second_place in any_place(),
    ) {
        let nodes = start_nodes()?;
        start_login_to_prompt(&nodes, first_place)?;

        let second = start_login(&nodes, second_place);

        prop_assert_eq!(second, Err(OPEN_LOGIN_PROBLEM.to_owned()));
        let shown = read_login(&nodes).map_err(fail)?;
        prop_assert_eq!(&shown["place"], first_place);
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_agent_login_desk_open_property_a_stop_frees_the_desk(
        place in any_place(),
        next_place in any_place(),
    ) {
        let nodes = start_nodes()?;
        start_login_to_prompt(&nodes, place)?;
        stop_login(&nodes).map_err(fail)?;

        start_login(&nodes, next_place).map_err(fail)?;

        let shown = read_login(&nodes).map_err(fail)?;
        prop_assert_eq!(&shown["place"], next_place);
        prop_assert_eq!(&shown["state"], RUNNING_STATE);
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_agent_login_desk_open_property_an_old_login_cannot_leak_in(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        start_login_to_prompt(&nodes, LOCAL_PLACE)?;
        stop_login(&nodes).map_err(fail)?;

        finish_login(&nodes, CONTAINER_PLACE, &code)?;

        let claude_login = read_status_field(&nodes, CLAUDE_LOGIN_FIELD)?;
        prop_assert_eq!(claude_login, NOT_LOGGED_IN_NAME);
        let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
        prop_assert_eq!(credential, LONG_LIVED_TOKEN_NAME);
    }

    #[test]
    fn test_agent_login_desk_read_property_nothing_open_reads_null(
        reads in 1..=MAXIMUM_REPEATS,
    ) {
        let nodes = start_nodes()?;

        for _ in 0..reads {
            prop_assert_eq!(read_login(&nodes).map_err(fail)?, Value::Null);
        }
    }

    #[test]
    fn test_agent_login_desk_read_property_a_stopped_login_reads_null(
        place in any_place(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        finish_login(&nodes, place, &code)?;

        stop_login(&nodes).map_err(fail)?;

        prop_assert_eq!(read_login(&nodes).map_err(fail)?, Value::Null);
    }

    #[test]
    fn test_agent_login_desk_type_keys_property_an_ended_login_is_refused(
        place in any_place(),
        code in any_login_code(),
        later_keys in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        finish_login(&nodes, place, &code)?;

        let typed = type_keys(&nodes, &typed_line(&later_keys));

        prop_assert_eq!(typed, Err(NO_LOGIN_PROBLEM.to_owned()));
    }

    #[test]
    fn test_agent_login_desk_type_keys_property_a_failed_login_is_refused(
        later_keys in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        fail_container_login(&nodes)?;

        let typed = type_keys(&nodes, &typed_line(&later_keys));

        prop_assert_eq!(typed, Err(NO_LOGIN_PROBLEM.to_owned()));
    }

    #[test]
    fn test_agent_login_desk_type_keys_property_nothing_open_is_refused(
        keys in any_login_code(),
        place in any_place(),
    ) {
        let nodes = start_nodes()?;
        let before_any_login = type_keys(&nodes, &keys);
        start_login_to_prompt(&nodes, place)?;
        stop_login(&nodes).map_err(fail)?;

        let after_a_stop = type_keys(&nodes, &keys);

        prop_assert_eq!(before_any_login, Err(NO_LOGIN_PROBLEM.to_owned()));
        prop_assert_eq!(after_a_stop, Err(NO_LOGIN_PROBLEM.to_owned()));
    }

    #[test]
    fn test_agent_login_desk_close_property_nothing_open_is_fine(
        stops in 1..=MAXIMUM_REPEATS,
    ) {
        let nodes = start_nodes()?;

        for _ in 0..stops {
            prop_assert_eq!(stop_login(&nodes), Ok(Value::Null));
        }
    }

    #[test]
    fn test_agent_login_desk_close_property_a_failed_login_is_cleared(
        next_place in any_place(),
    ) {
        let nodes = start_nodes()?;
        fail_container_login(&nodes)?;

        prop_assert_eq!(stop_login(&nodes), Ok(Value::Null));

        prop_assert_eq!(read_login(&nodes).map_err(fail)?, Value::Null);
        start_login(&nodes, next_place).map_err(fail)?;
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_agent_login_desk_close_property_a_running_login_is_cleared(
        place in any_place(),
        unfinished_code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        start_login_to_prompt(&nodes, place)?;
        type_keys(&nodes, &unfinished_code).map_err(fail)?;

        prop_assert_eq!(stop_login(&nodes), Ok(Value::Null));

        prop_assert_eq!(read_login(&nodes).map_err(fail)?, Value::Null);
        let typed = type_keys(&nodes, &typed_line(&unfinished_code));
        prop_assert_eq!(typed, Err(NO_LOGIN_PROBLEM.to_owned()));
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(MODEL_CASES))]

    #[test]
    fn test_lock_session_property_follows_the_desk_model(
        actions in any_desk_actions(),
    ) {
        let nodes = start_nodes()?;

        play_against_the_model(&nodes, &actions)?;

        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_lock_session_property_a_stop_always_empties_the_desk(
        actions in any_desk_actions(),
        place in any_place(),
    ) {
        let nodes = start_nodes()?;
        play_against_the_model(&nodes, &actions)?;

        stop_login(&nodes).map_err(fail)?;

        prop_assert_eq!(read_login(&nodes).map_err(fail)?, Value::Null);
        start_login(&nodes, place).map_err(fail)?;
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_lock_session_property_a_finished_container_login_is_kept(
        actions in any_desk_actions(),
    ) {
        let nodes = start_nodes()?;

        let visited_models = play_against_the_model(&nodes, &actions)?;

        let container_ending = ModelLogin::Ended(CONTAINER_PLACE);
        let expected = if visited_models.contains(&container_ending) {
            Value::from(LONG_LIVED_TOKEN_NAME)
        } else {
            Value::Null
        };
        let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
        prop_assert_eq!(credential, expected);
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_agent_login_desk_read_property_follows_the_desk_model(
        actions in any_desk_actions(),
        reads in 1..=MAXIMUM_REPEATS,
    ) {
        let nodes = start_nodes()?;
        play_against_the_model(&nodes, &actions)?;
        let settled = read_login(&nodes).map_err(fail)?;

        for _ in 0..reads {
            prop_assert_eq!(&read_login(&nodes).map_err(fail)?, &settled);
        }

        stop_login(&nodes).map_err(fail)?;
    }
}

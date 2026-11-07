use std::time::{Duration, Instant};

use proptest::prelude::*;
use serde_json::Value;

use crate::login_steps::{
    API_KEY_NAME, CONTAINER_PLACE, CREDENTIAL_KIND_FIELD, ENTER_KEY,
    FINISHED_STATE, LOCAL_PLACE, LOGIN_CASES, RUNNING_STATE, TOKEN_START,
    any_login_code, any_place, fail_container_login, finish_login,
    read_kept_secret, read_login, read_status_field, save_api_key,
    start_login_to_prompt, start_nodes, stop_login, type_keys,
};
use crate::support::login_runner::LoginRunner;
use crate::support::test_device::fail;

const LONG_LIVED_TOKEN_NAME: &str = "long_lived_token";
const TOKEN_ADVICE: &str = "Store this token securely";
const TERMINAL_ESCAPE: char = '\u{1b}';
const API_KEY: &str = "sk-ant-api03-saved-key";
const FOLLOW_LIMIT: Duration = Duration::from_secs(20);
const MAXIMUM_REREADS: usize = 4;

fn read_until_ended(
    nodes: &LoginRunner,
    mut readings: Vec<Value>,
) -> Result<Vec<Value>, TestCaseError> {
    let deadline = Instant::now() + FOLLOW_LIMIT;
    loop {
        let reading = read_login(nodes).map_err(fail)?;
        let has_ended = reading["state"] != RUNNING_STATE;
        readings.push(reading);
        if has_ended {
            return Ok(readings);
        }
        if Instant::now() >= deadline {
            return Err(TestCaseError::fail("the login never ended"));
        }
    }
}

fn type_code_and_follow(
    nodes: &LoginRunner,
    place: &str,
    code: &str,
) -> Result<Vec<Value>, TestCaseError> {
    start_login_to_prompt(nodes, place)?;
    let reading_before_typing = read_login(nodes).map_err(fail)?;
    type_keys(nodes, &format!("{code}{ENTER_KEY}")).map_err(fail)?;
    read_until_ended(nodes, vec![reading_before_typing])
}

fn count_state_changes(readings: &[Value]) -> usize {
    let mut changes = 0;
    for pair in readings.windows(2) {
        if pair[0]["state"] != pair[1]["state"] {
            changes += 1;
        }
    }
    changes
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LOGIN_CASES))]

    #[test]
    fn test_follow_property_a_login_ends_when_the_program_exits(
        place in any_place(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let ending = finish_login(&nodes, place, &code)?;

        prop_assert_eq!(&ending["state"], FINISHED_STATE);
    }

    #[test]
    fn test_follow_property_a_tokenless_container_login_fails(
        reads in 1..=MAXIMUM_REREADS,
    ) {
        let nodes = start_nodes()?;

        let ending = fail_container_login(&nodes)?;

        for _ in 0..reads {
            prop_assert_eq!(&read_login(&nodes).map_err(fail)?, &ending);
        }
        let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
        prop_assert_eq!(credential, Value::Null);
    }

    #[test]
    fn test_follow_property_an_ending_never_changes_afterwards(
        place in any_place(),
        code in any_login_code(),
        reads in 1..=MAXIMUM_REREADS,
    ) {
        let nodes = start_nodes()?;
        let ending = finish_login(&nodes, place, &code)?;

        for _ in 0..reads {
            prop_assert_eq!(&read_login(&nodes).map_err(fail)?, &ending);
        }
    }

    #[test]
    fn test_take_output_property_the_printed_token_is_kept_exactly(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        finish_login(&nodes, CONTAINER_PLACE, &code)?;

        let kept_secret = read_kept_secret(&nodes).map_err(fail)?;
        prop_assert_eq!(kept_secret, format!("{TOKEN_START}{code}"));
    }

    #[test]
    fn test_take_output_property_shown_lines_carry_no_terminal_codes(
        place in any_place(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let readings = type_code_and_follow(&nodes, place, &code)?;

        for reading in readings {
            let lines = reading["lines"].to_string();
            prop_assert!(!lines.contains(TERMINAL_ESCAPE), "{lines}");
            prop_assert!(!lines.contains("\\u001b"), "{lines}");
        }
    }

    #[test]
    fn test_take_output_property_the_whole_output_reaches_the_lines(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let ending = finish_login(&nodes, CONTAINER_PLACE, &code)?;

        prop_assert!(ending["lines"].to_string().contains(TOKEN_ADVICE));
    }

    #[test]
    fn test_settle_property_a_connected_login_keeps_the_credential(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        save_api_key(&nodes, API_KEY).map_err(fail)?;

        finish_login(&nodes, CONTAINER_PLACE, &code)?;

        let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
        prop_assert_eq!(credential, LONG_LIVED_TOKEN_NAME);
    }

    #[test]
    fn test_settle_property_a_local_login_keeps_the_saved_key(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        save_api_key(&nodes, API_KEY).map_err(fail)?;

        finish_login(&nodes, LOCAL_PLACE, &code)?;

        let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
        prop_assert_eq!(credential, API_KEY_NAME);
        prop_assert_eq!(read_kept_secret(&nodes).map_err(fail)?, API_KEY);
    }

    #[test]
    fn test_settle_property_a_failed_login_keeps_the_saved_key(
        reads in 1..=MAXIMUM_REREADS,
    ) {
        let nodes = start_nodes()?;
        save_api_key(&nodes, API_KEY).map_err(fail)?;

        fail_container_login(&nodes)?;

        for _ in 0..reads {
            let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
            prop_assert_eq!(credential, API_KEY_NAME);
        }
        prop_assert_eq!(read_kept_secret(&nodes).map_err(fail)?, API_KEY);
    }

    #[test]
    fn test_lock_progress_property_states_only_move_forward(
        place in any_place(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let readings = type_code_and_follow(&nodes, place, &code)?;

        prop_assert!(count_state_changes(&readings) <= 1, "{readings:?}");
        prop_assert_eq!(&readings[0]["state"], RUNNING_STATE);
    }

    #[test]
    fn test_lock_progress_property_reads_keep_answering_while_it_writes(
        place in any_place(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let readings = type_code_and_follow(&nodes, place, &code)?;

        for reading in &readings {
            prop_assert!(reading["lines"].is_array(), "{reading}");
            prop_assert_eq!(&reading["place"], place);
        }
    }

    #[test]
    fn test_lock_progress_property_a_stop_while_it_writes_returns(
        place in any_place(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        start_login_to_prompt(&nodes, place)?;
        type_keys(&nodes, &format!("{code}{ENTER_KEY}")).map_err(fail)?;

        let stopped = stop_login(&nodes);

        prop_assert_eq!(stopped, Ok(Value::Null));
        prop_assert_eq!(read_login(&nodes).map_err(fail)?, Value::Null);
    }
}

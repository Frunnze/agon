use proptest::prelude::*;
use serde_json::Value;

use crate::login_steps::{
    CLAUDE_LOGIN_FIELD, CONTAINER_PLACE, CREDENTIAL_KIND_FIELD,
    FINISHED_STATE, LOCAL_PLACE, LOGIN_CASES, any_login_code, any_place,
    finish_login, read_login, read_status_field, start_login,
    start_login_to_prompt, start_nodes, start_nodes_without_claude,
    stop_login,
};
use crate::support::test_device::fail;

const TOKEN_HEADING: &str = "Your OAuth token";
const LOGGED_IN_NAME: &str = "logged_in";
const NOT_LOGGED_IN_NAME: &str = "not_logged_in";
const PROGRAM_NAME: &str = "claude";
const WORD_SEPARATOR: char = ' ';

fn read_command(shown: &Value) -> String {
    shown["command"].as_str().unwrap_or_default().to_owned()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LOGIN_CASES))]

    #[test]
    fn test_choose_login_arguments_property_a_container_gets_a_token(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let ending = finish_login(&nodes, CONTAINER_PLACE, &code)?;

        prop_assert!(ending["lines"].to_string().contains(TOKEN_HEADING));
        let claude_login = read_status_field(&nodes, CLAUDE_LOGIN_FIELD)?;
        prop_assert_eq!(claude_login, NOT_LOGGED_IN_NAME);
    }

    #[test]
    fn test_choose_login_arguments_property_a_local_login_signs_in_here(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let ending = finish_login(&nodes, LOCAL_PLACE, &code)?;

        prop_assert!(!ending["lines"].to_string().contains(TOKEN_HEADING));
        let claude_login = read_status_field(&nodes, CLAUDE_LOGIN_FIELD)?;
        prop_assert_eq!(claude_login, LOGGED_IN_NAME);
        let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
        prop_assert_eq!(credential, Value::Null);
    }

    #[test]
    fn test_choose_login_arguments_property_places_differ_in_command(
        first_code in any_login_code(),
        second_code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let container = finish_login(&nodes, CONTAINER_PLACE, &first_code)?;
        let local = finish_login(&nodes, LOCAL_PLACE, &second_code)?;

        prop_assert_ne!(read_command(&container), read_command(&local));
    }

    #[test]
    fn test_describe_login_command_property_needs_claude_on_the_path(
        place in any_place(),
        attempts in 1_usize..3,
    ) {
        let nodes = start_nodes_without_claude()?;

        for _ in 0..attempts {
            prop_assert!(start_login(&nodes, place).is_err());
        }

        prop_assert_eq!(read_login(&nodes).map_err(fail)?, Value::Null);
    }

    #[test]
    fn test_describe_login_command_property_keeps_the_node_environment(
        place in any_place(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let ending = finish_login(&nodes, place, &code)?;

        prop_assert_eq!(&ending["state"], FINISHED_STATE, "{}", ending);
    }

    #[test]
    fn test_describe_login_command_property_shows_the_program_it_runs(
        place in any_place(),
    ) {
        let nodes = start_nodes()?;

        start_login_to_prompt(&nodes, place)?;

        let command = read_command(&read_login(&nodes).map_err(fail)?);
        let program = command.split(WORD_SEPARATOR).next();
        prop_assert_eq!(program, Some(PROGRAM_NAME));
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_describe_command_text_property_has_single_spaces(
        place in any_place(),
    ) {
        let nodes = start_nodes()?;

        start_login(&nodes, place).map_err(fail)?;

        let command = read_command(&read_login(&nodes).map_err(fail)?);
        prop_assert_eq!(command.trim(), command.as_str());
        prop_assert!(!command.contains("  "), "{command}");
        prop_assert!(command.split(WORD_SEPARATOR).count() >= 2);
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_describe_command_text_property_is_the_same_each_time(
        place in any_place(),
        first_code in any_login_code(),
        second_code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let first = finish_login(&nodes, place, &first_code)?;
        let second = finish_login(&nodes, place, &second_code)?;

        prop_assert_eq!(read_command(&first), read_command(&second));
    }

    #[test]
    fn test_describe_command_text_property_holds_no_typed_code(
        place in any_place(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let ending = finish_login(&nodes, place, &code)?;

        let command = read_command(&ending);
        let words: Vec<&str> = command.split(WORD_SEPARATOR).collect();
        prop_assert!(!words.contains(&code.as_str()), "{command}");
    }
}

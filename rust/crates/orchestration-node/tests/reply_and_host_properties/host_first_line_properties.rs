use std::fs;

use proptest::prelude::*;
use serde_json::Value;
use tempfile::TempDir;

use crate::host_inputs::{
    STATUS_COMMAND, hostile_text_line_strategy, invalid_utf8_line_strategy,
};
use crate::host_runs::{
    HostRun, join_input_lines, parse_reply_lines, quiet_configuration,
    run_host,
};
use crate::support::test_device::{fail, is_defined_reply};

const MISSING_CONFIGURATION: &str =
    "the first input line must be the node configuration";
const FAILURE_EXIT_CODE: i32 = 1;
const HOST_CASES: u32 = 6;
const LATER_COMMAND_LIMIT: usize = 3;
const ERROR_FIELD: &str = "error";
const DATA_DIRECTORY_FIELD: &str = "data_directory";
const FIELD_NAME_PATTERN: &str = "[a-z_]{1,16}";
const KNOWN_CONFIGURATION_FIELDS: [&str; 6] = [
    "data_directory",
    "identity_store",
    "runner",
    "peer_relay",
    "app_server_port",
    "server_takeover_seconds",
];
const BLOCKING_FILE_NAME: &str = "not-a-folder";

fn later_commands_strategy() -> impl Strategy<Value = Vec<Vec<u8>>> {
    let status_line = Just(STATUS_COMMAND.as_bytes().to_vec());
    prop::collection::vec(status_line, 0..LATER_COMMAND_LIMIT)
}

fn run_with_first_line(
    first_line: Vec<u8>,
    later_commands: Vec<Vec<u8>>,
) -> Result<HostRun, TestCaseError> {
    let mut input_lines = vec![first_line];
    input_lines.extend(later_commands);
    run_host(&join_input_lines(&input_lines)).map_err(fail)
}

fn read_only_error(host_run: &HostRun) -> Result<String, TestCaseError> {
    let replies = parse_reply_lines(host_run).map_err(fail)?;
    prop_assert_eq!(replies.len(), 1, "{:?}", host_run);
    let reply = &replies[0];
    prop_assert!(is_defined_reply(reply), "{reply}");
    let message = reply.get(ERROR_FIELD).and_then(Value::as_str);
    let Some(message) = message else {
        return Err(TestCaseError::fail(format!("no error in {reply}")));
    };
    prop_assert_eq!(host_run.exit_code, Some(FAILURE_EXIT_CODE));
    Ok(message.to_owned())
}

fn is_unknown_configuration_field(field_name: &str) -> bool {
    !KNOWN_CONFIGURATION_FIELDS.contains(&field_name)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOST_CASES))]

    #[test]
    fn test_fail_with_property_a_first_line_that_is_not_text_is_refused(
        first_line in invalid_utf8_line_strategy(),
        later_commands in later_commands_strategy(),
    ) {
        let host_run = run_with_first_line(first_line, later_commands)?;

        let message = read_only_error(&host_run)?;
        prop_assert_eq!(message, MISSING_CONFIGURATION);
    }

    #[test]
    fn test_fail_with_property_text_that_is_no_configuration_is_refused(
        first_line in hostile_text_line_strategy(),
        later_commands in later_commands_strategy(),
    ) {
        let first_line_bytes = first_line.into_bytes();

        let host_run = run_with_first_line(first_line_bytes, later_commands)?;

        let message = read_only_error(&host_run)?;
        prop_assert!(!message.is_empty());
    }

    #[test]
    fn test_fail_with_property_an_unknown_configuration_field_is_refused(
        field_name in FIELD_NAME_PATTERN.prop_filter(
            "the field is unknown",
            |field_name| is_unknown_configuration_field(field_name),
        ),
        field_value in hostile_text_line_strategy(),
        later_commands in later_commands_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let mut configuration = quiet_configuration(&data_directory);
        configuration[field_name.as_str()] = Value::String(field_value);
        let first_line = configuration.to_string().into_bytes();

        let host_run = run_with_first_line(first_line, later_commands)?;

        let message = read_only_error(&host_run)?;
        prop_assert!(message.contains(&field_name), "{message}");
        let left_entries = fs::read_dir(data_directory.path())
            .map_err(fail)?
            .count();
        prop_assert_eq!(left_entries, 0);
    }

    #[test]
    fn test_fail_with_property_a_data_directory_that_is_a_file_is_refused(
        later_commands in later_commands_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let blocking_file = data_directory.path().join(BLOCKING_FILE_NAME);
        fs::write(&blocking_file, b"").map_err(fail)?;
        let mut configuration = quiet_configuration(&data_directory);
        configuration[DATA_DIRECTORY_FIELD] =
            Value::String(blocking_file.display().to_string());
        let first_line = configuration.to_string().into_bytes();

        let host_run = run_with_first_line(first_line, later_commands)?;

        let message = read_only_error(&host_run)?;
        prop_assert!(!message.is_empty());
    }
}

#[test]
fn test_fail_with_property_no_input_at_all_is_refused() {
    let host_run = run_host(&[]);

    let Ok(host_run) = host_run else {
        panic!("the host runs: {host_run:?}");
    };
    let message =
        read_only_error(&host_run).map_err(|error| error.to_string());
    assert_eq!(message, Ok(MISSING_CONFIGURATION.to_owned()));
}

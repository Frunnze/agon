use proptest::prelude::*;
use serde_json::Value;
use tempfile::TempDir;

use crate::host_inputs::{
    STATUS_COMMAND, hostile_text_line_strategy, invalid_utf8_line_strategy,
    unknown_command_strategy,
};
use crate::host_runs::{
    HostRun, join_input_lines, parse_reply_lines, quiet_configuration,
    run_host,
};
use crate::support::test_device::{fail, is_defined_reply};

const SUCCESS_EXIT_CODE: i32 = 0;
const HOST_CASES: u32 = 6;
const COMMAND_LINE_LIMIT: usize = 4;
const SUCCESS_FIELD: &str = "ok";
const ERROR_FIELD: &str = "error";
const CARRIAGE_RETURN: u8 = b'\r';

type InputLines = Vec<Vec<u8>>;

fn run_configured_host(
    command_input: &[u8],
) -> Result<HostRun, TestCaseError> {
    let data_directory = TempDir::new().map_err(fail)?;
    let configuration = quiet_configuration(&data_directory);
    let configuration_line = configuration.to_string().into_bytes();
    let mut input = join_input_lines(&[configuration_line]);
    input.extend_from_slice(command_input);
    run_host(&input).map_err(fail)
}

fn read_command_replies(
    host_run: &HostRun,
    command_count: usize,
) -> Result<Vec<Value>, TestCaseError> {
    let replies = parse_reply_lines(host_run).map_err(fail)?;
    prop_assert_eq!(replies.len(), command_count + 1, "{:?}", host_run);
    let started = replies[0].get(SUCCESS_FIELD);
    prop_assert_eq!(started, Some(&Value::Null), "{:?}", host_run);
    for reply in &replies {
        prop_assert!(is_defined_reply(reply), "{reply}");
    }
    prop_assert_eq!(host_run.exit_code, Some(SUCCESS_EXIT_CODE));
    Ok(replies[1..].to_vec())
}

fn text_lines_strategy() -> impl Strategy<Value = InputLines> {
    let text_line = hostile_text_line_strategy().prop_map(String::into_bytes);
    prop::collection::vec(text_line, 0..COMMAND_LINE_LIMIT)
}

fn unknown_command_lines_strategy() -> impl Strategy<Value = InputLines> {
    let command_line = unknown_command_strategy().prop_map(String::into_bytes);
    prop::collection::vec(command_line, 1..COMMAND_LINE_LIMIT)
}

fn end_with_carriage_returns(command_lines: &[Vec<u8>]) -> InputLines {
    let mut windows_lines = Vec::new();
    for command_line in command_lines {
        let mut windows_line = command_line.clone();
        windows_line.push(CARRIAGE_RETURN);
        windows_lines.push(windows_line);
    }
    windows_lines
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOST_CASES))]

    #[test]
    fn test_main_property_answers_every_command_line_with_one_reply(
        command_lines in text_lines_strategy(),
    ) {
        let command_input = join_input_lines(&command_lines);

        let host_run = run_configured_host(&command_input)?;

        read_command_replies(&host_run, command_lines.len())?;
    }

    #[test]
    fn test_main_property_answers_a_command_line_that_is_not_text(
        invalid_line in invalid_utf8_line_strategy(),
        lines_before in text_lines_strategy(),
    ) {
        let invalid_line_index = lines_before.len();
        let mut command_lines = lines_before;
        command_lines.push(invalid_line);
        command_lines.push(STATUS_COMMAND.as_bytes().to_vec());
        let command_input = join_input_lines(&command_lines);

        let host_run = run_configured_host(&command_input)?;

        let replies = read_command_replies(&host_run, command_lines.len())?;
        let invalid_reply = &replies[invalid_line_index];
        prop_assert!(invalid_reply.get(ERROR_FIELD).is_some());
        let status_reply = &replies[invalid_line_index + 1];
        prop_assert!(status_reply.get(SUCCESS_FIELD).is_some());
    }

    #[test]
    fn test_main_property_ends_cleanly_once_input_closes(
        status_count in 0..COMMAND_LINE_LIMIT,
        drops_last_line_end in any::<bool>(),
    ) {
        let status_line = STATUS_COMMAND.as_bytes().to_vec();
        let mut command_input =
            join_input_lines(&vec![status_line; status_count]);
        if drops_last_line_end {
            command_input.pop();
        }

        let host_run = run_configured_host(&command_input)?;

        let replies = read_command_replies(&host_run, status_count)?;
        for reply in &replies {
            prop_assert!(reply.get(SUCCESS_FIELD).is_some(), "{reply}");
        }
    }

    #[test]
    fn test_main_property_windows_line_ends_give_the_same_replies(
        command_lines in unknown_command_lines_strategy(),
    ) {
        let windows_lines = end_with_carriage_returns(&command_lines);

        let plain_input = join_input_lines(&command_lines);
        let windows_input = join_input_lines(&windows_lines);

        let plain_run = run_configured_host(&plain_input)?;
        let windows_run = run_configured_host(&windows_input)?;

        let command_count = command_lines.len();
        let plain_replies = read_command_replies(&plain_run, command_count)?;
        let windows_replies =
            read_command_replies(&windows_run, command_count)?;
        prop_assert_eq!(plain_replies, windows_replies);
    }
}

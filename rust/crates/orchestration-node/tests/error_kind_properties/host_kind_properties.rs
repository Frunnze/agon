use orchestration_node::command_reply::render_node_error_reply;
use orchestration_node::node_configuration::NodeConfiguration;
use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::error_kind_samples::{
    ERROR_FIELD, NO_ACCOUNT_COMMANDS, build_account_command, no_account_reply,
    read_kind,
};
use crate::host_runs::{
    HostRun, join_input_lines, parse_reply_lines, quiet_configuration,
    run_host,
};
use crate::support::test_device::fail;

const HOST_CASES: u32 = 4;
const MISSING_CONFIGURATION: &str =
    "the first input line must be the node configuration";
const FAILURE_EXIT_CODE: i32 = 1;
const PRINTABLE_LINE_PATTERN: &str = "[ -~]{0,30}";
const FIELD_NAME_PATTERN: &str = "[a-z_]{1,12}";
const MOST_COMMANDS: usize = 4;
const INVALID_UTF8_BYTES: [u8; 4] = [0x80, 0xBF, 0xFE, 0xFF];
const LONGEST_INVALID_LINE: usize = 4;

fn invalid_configuration_strategy() -> impl Strategy<Value = String> {
    let object_line = (FIELD_NAME_PATTERN, any::<i64>())
        .prop_map(|(field, number)| json!({ field: number }).to_string());
    prop_oneof![PRINTABLE_LINE_PATTERN.prop_map(String::from), object_line]
        .prop_filter("refused", |line| {
            NodeConfiguration::from_json(line).is_err()
        })
}

fn missing_configuration_strategy() -> impl Strategy<Value = Vec<u8>> {
    let invalid_line = prop::collection::vec(
        select(INVALID_UTF8_BYTES.to_vec()),
        1..LONGEST_INVALID_LINE,
    )
    .prop_map(|line| join_input_lines(&[line]));
    prop_oneof![Just(Vec::new()), invalid_line]
}

fn run_lines(input_lines: &[Vec<u8>]) -> Result<Vec<Value>, TestCaseError> {
    let host_run: HostRun =
        run_host(&join_input_lines(input_lines)).map_err(fail)?;
    parse_reply_lines(&host_run).map_err(fail)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOST_CASES))]

    #[test]
    fn test_main_property_a_start_refusal_renders_like_a_node_error_reply(
        configuration_line in invalid_configuration_strategy(),
    ) {
        let refusal = NodeConfiguration::from_json(&configuration_line)
            .err()
            .ok_or_else(|| fail("the configuration was accepted"))?;
        let expected_reply: Value =
            serde_json::from_str(&render_node_error_reply(&refusal))
                .map_err(fail)?;

        let host_run =
            run_host(&join_input_lines(&[configuration_line.into_bytes()]))
                .map_err(fail)?;

        let replies = parse_reply_lines(&host_run).map_err(fail)?;
        prop_assert_eq!(replies, vec![expected_reply]);
        prop_assert_eq!(host_run.exit_code, Some(FAILURE_EXIT_CODE));
    }

    #[test]
    fn test_main_property_no_account_commands_name_their_kind(
        names in prop::collection::vec(
            select(NO_ACCOUNT_COMMANDS.to_vec()),
            1..MOST_COMMANDS,
        ),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let configuration_line =
            quiet_configuration(&data_directory).to_string();
        let mut input_lines = vec![configuration_line.into_bytes()];
        for name in &names {
            let command = build_account_command(name, 0);
            input_lines.push(command.to_string().into_bytes());
        }

        let replies = run_lines(&input_lines)?;

        prop_assert_eq!(replies.len(), names.len() + 1);
        for reply in &replies[1..] {
            prop_assert_eq!(reply, &no_account_reply());
        }
    }

    #[test]
    fn test_fail_with_property_a_missing_configuration_has_no_kind(
        input in missing_configuration_strategy(),
    ) {
        let host_run = run_host(&input).map_err(fail)?;

        let replies = parse_reply_lines(&host_run).map_err(fail)?;
        let expected_reply = json!({ ERROR_FIELD: MISSING_CONFIGURATION });
        prop_assert_eq!(&replies, &vec![expected_reply]);
        prop_assert_eq!(read_kind(&replies[0]), None);
        prop_assert_eq!(host_run.exit_code, Some(FAILURE_EXIT_CODE));
    }
}

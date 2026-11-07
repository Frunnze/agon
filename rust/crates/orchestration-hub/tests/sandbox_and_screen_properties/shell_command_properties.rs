use std::process::Command;

use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;
use proptest::sample::select;

use crate::agent_reading::parse_agent_line;
use crate::codex_lines::{command_item, started_line};

const SHELLS: [&str; 5] = ["bash", "/bin/bash", "/bin/zsh", "sh", "zsh"];
const OTHER_PROGRAMS: [&str; 5] =
    ["python", "/opt/fish", "bashful", "bash -x", "node"];
const SHELL_CASES: u32 = 64;
const SCRIPT_PATTERN: &str = "[!-~é中😀]|[!-~é中😀][ -~é中😀]{0,40}[!-~é中😀]";
const PLAIN_WORD_PATTERN: &str = "[a-z0-9./=-]{1,10}";

fn quote_singly(script: &str) -> String {
    format!("'{}'", script.replace('\'', r"'\''"))
}

fn quote_doubly(script: &str) -> String {
    let mut quoted = String::from("\"");
    for character in script.chars() {
        if matches!(character, '"' | '\\' | '$' | '`') {
            quoted.push('\\');
        }
        quoted.push(character);
    }
    quoted.push('"');
    quoted
}

fn quote_with_backslashes(script: &str) -> String {
    let mut quoted = String::new();
    for character in script.chars() {
        if !character.is_ascii_alphanumeric() {
            quoted.push('\\');
        }
        quoted.push(character);
    }
    quoted
}

fn print_with_sh(quoted: &str) -> Result<String, TestCaseError> {
    let output = Command::new("/bin/sh")
        .arg("-c")
        .arg(format!("printf %s {quoted}"))
        .output()
        .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

fn describe_started_command(command: &str) -> Vec<AgentEvent> {
    let item = command_item(command, "in_progress", "");
    parse_agent_line(AgentKind::Codex, &started_line(&item))
}

fn ran(script: &str) -> Vec<AgentEvent> {
    vec![AgentEvent::UsedTool(format!("Ran {script}"))]
}

fn check_round_trip(
    shell: &str,
    quoted: &str,
    script: &str,
) -> Result<(), TestCaseError> {
    prop_assert_eq!(print_with_sh(quoted)?, script);

    let command = format!("{shell} -lc {quoted}");

    prop_assert_eq!(describe_started_command(&command), ran(script));
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SHELL_CASES))]

    #[test]
    fn test_unwrap_shell_command_property_single_quotes_round_trip_via_sh(
        shell in select(SHELLS.to_vec()),
        script in SCRIPT_PATTERN,
    ) {
        check_round_trip(shell, &quote_singly(&script), &script)?;
    }

    #[test]
    fn test_unwrap_shell_command_property_double_quotes_round_trip_via_sh(
        shell in select(SHELLS.to_vec()),
        script in SCRIPT_PATTERN,
    ) {
        check_round_trip(shell, &quote_doubly(&script), &script)?;
    }

    #[test]
    fn test_unwrap_shell_command_property_backslashes_round_trip_via_sh(
        shell in select(SHELLS.to_vec()),
        script in SCRIPT_PATTERN,
    ) {
        check_round_trip(shell, &quote_with_backslashes(&script), &script)?;
    }

    #[test]
    fn test_unwrap_shell_command_property_other_programs_stay_whole(
        program in select(OTHER_PROGRAMS.to_vec()),
        word in PLAIN_WORD_PATTERN,
    ) {
        let command = format!("{program} -lc '{word}'");

        prop_assert_eq!(describe_started_command(&command), ran(&command));
    }

    #[test]
    fn test_strip_surrounding_quotes_property_unquoted_words_stay_as_written(
        shell in select(SHELLS.to_vec()),
        words in proptest::collection::vec(PLAIN_WORD_PATTERN, 2..5),
    ) {
        let script = words.join(" ");
        let command = format!("{shell} -lc {script}");

        prop_assert_eq!(describe_started_command(&command), ran(&script));
    }

    #[test]
    fn test_strip_surrounding_quotes_property_unbalanced_inner_quote_is_kept(
        shell in select(SHELLS.to_vec()),
        quote in select(vec!['\'', '"']),
        before in PLAIN_WORD_PATTERN,
        after in PLAIN_WORD_PATTERN,
    ) {
        let script = format!("{before}{quote}{after}");
        let command = format!("{shell} -lc {quote}{script}{quote}");

        prop_assert_eq!(describe_started_command(&command), ran(&script));
    }

    #[test]
    fn test_strip_surrounding_quotes_property_mismatched_quotes_stay(
        shell in select(SHELLS.to_vec()),
        word in PLAIN_WORD_PATTERN,
    ) {
        let script = format!("'{word}\"");
        let command = format!("{shell} -lc {script}");

        prop_assert_eq!(describe_started_command(&command), ran(&script));
    }
}

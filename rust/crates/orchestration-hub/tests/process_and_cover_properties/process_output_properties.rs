use orchestration_hub::piped_process::PipedProcess;
use orchestration_hub::process_supervisor::{ProcessExit, start_process};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::process_support::{
    CaseOutcome, any_signal_name, finish_within_time_limit, read_every_line,
    read_next_line, run_piped_to_end, shell_command, start_piped,
};
use crate::target_folders::fail_with;

const PROCESS_CASES: u32 = 6;
const PRINT_FIRST_ARGUMENT: &str = "printf '%s' \"$1\"";
const PRINT_AROUND_A_BROKEN_BYTE: &str = "printf '%s\\377%s\\n' \"$1\" \"$2\"";
const REPLACEMENT_CHARACTER: char = '\u{FFFD}';
const LINE_ENDINGS: [&str; 3] = ["\n", "\r\n", "\r\r\n"];
const PRINT_SLOWLY: &str =
    "for word in \"$@\"; do printf '%s\\n' \"$word\"; sleep 0.05; done";

fn any_line_piece() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9é中😀 \\t.,:;_-]{0,16}"
}

fn split_into_expected_lines(text: &str) -> Vec<String> {
    let mut lines: Vec<String> = text.split('\n').map(String::from).collect();
    if text.ends_with('\n') || text.is_empty() {
        lines.pop();
    }
    lines
}

fn kill_with_signal(signal_name: &str) -> Result<ProcessExit, TestCaseError> {
    let script = format!("kill -s {signal_name} $$; sleep 30");
    let (_lines, exit) = run_piped_to_end(&shell_command(&script, &[]))?;
    Ok(exit)
}

fn terminal_exit_for(script: &str) -> Result<ProcessExit, TestCaseError> {
    let mut process = start_process(&shell_command(script, &[]))
        .map_err(|problem| fail_with(&problem))?;
    read_every_line(&mut process);
    process
        .wait_for_exit()
        .map_err(|problem| fail_with(&problem))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROCESS_CASES))]

    #[test]
    fn test_forward_output_lines_property_splits_text_at_line_feeds(
        pieces in vec(any_line_piece(), 0..6),
        ends_with_line_feed in any::<bool>(),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut text = pieces.join("\n");
            if ends_with_line_feed {
                text.push('\n');
            }
            let command = shell_command(PRINT_FIRST_ARGUMENT, &[text.clone()]);

            let (lines, _exit) = run_piped_to_end(&command)?;

            prop_assert_eq!(lines, split_into_expected_lines(&text));
            Ok(())
        })?;
    }

    #[test]
    fn test_forward_output_lines_property_drops_carriage_returns_at_ends(
        pieces in vec(any_line_piece(), 1..6),
        ending_choices in vec(0..LINE_ENDINGS.len(), 6),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut text = String::new();
            for (piece, ending) in pieces.iter().zip(&ending_choices) {
                text.push_str(piece);
                text.push_str(LINE_ENDINGS[*ending]);
            }
            let command = shell_command(PRINT_FIRST_ARGUMENT, &[text]);

            let (lines, _exit) = run_piped_to_end(&command)?;

            prop_assert_eq!(lines, pieces);
            Ok(())
        })?;
    }

    #[test]
    fn test_forward_output_lines_property_replaces_broken_bytes(
        before in any_line_piece(),
        after in any_line_piece(),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let arguments = vec![before.clone(), after.clone()];
            let command =
                shell_command(PRINT_AROUND_A_BROKEN_BYTE, &arguments);

            let (lines, _exit) = run_piped_to_end(&command)?;

            let expected = format!("{before}{REPLACEMENT_CHARACTER}{after}");
            prop_assert_eq!(lines, vec![expected]);
            Ok(())
        })?;
    }

    #[test]
    fn test_describe_exit_status_property_reads_back_every_code(
        code in 0_u32..256,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let script = format!("exit {code}");

            let command = shell_command(&script, &[]);

            let (_lines, exit) = run_piped_to_end(&command)?;

            let expected = if code == 0 {
                ProcessExit::Succeeded
            } else {
                ProcessExit::FailedWithCode(code)
            };
            prop_assert_eq!(&exit, &expected);
            prop_assert_eq!(terminal_exit_for(&script)?, expected);
            Ok(())
        })?;
    }

    #[test]
    fn test_describe_exit_status_property_names_the_ending_signal(
        signal_name in any_signal_name(),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let exit = kill_with_signal(signal_name)?;

            let ProcessExit::KilledBySignal(described) = exit else {
                return Err(TestCaseError::fail(format!("{exit:?}")));
            };
            prop_assert!(!described.trim().is_empty());
            Ok(())
        })?;
    }

    #[test]
    fn test_describe_exit_status_property_distinct_signals_stay_apart(
        first_signal in any_signal_name(),
        second_signal in any_signal_name(),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let first_exit = kill_with_signal(first_signal)?;
            let second_exit = kill_with_signal(second_signal)?;

            let exits_match = first_exit == second_exit;
            prop_assert_eq!(exits_match, first_signal == second_signal);
            Ok(())
        })?;
    }

    #[test]
    fn test_running_process_new_property_keeps_the_output_open_until_the_end(
        words in vec("[a-z]{1,8}", 1..5),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let (lines, exit) =
                run_piped_to_end(&shell_command(PRINT_SLOWLY, &words))?;

            prop_assert_eq!(lines, words);
            prop_assert_eq!(exit, ProcessExit::Succeeded);
            Ok(())
        })?;
    }

    #[test]
    fn test_running_process_new_property_keeps_the_child_it_was_given(
        code in 1_u32..256,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let script = format!("echo $$; exit {code}");

            let command = shell_command(&script, &[]);

            let (lines, exit) = run_piped_to_end(&command)?;

            prop_assert_eq!(lines.len(), 1);
            prop_assert_eq!(exit, ProcessExit::FailedWithCode(code));
            Ok(())
        })?;
    }

    #[test]
    fn test_running_process_new_property_stops_the_child_it_was_given(
        _attempt in 0_u8..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let command = shell_command("echo started; sleep 30", &[]);
            let PipedProcess { mut process, input_lines } =
                start_piped(&command)?;
            read_next_line(&mut process)?;

            process.stop().map_err(|problem| fail_with(&problem))?;
            let exit = process
                .wait_for_exit()
                .map_err(|problem| fail_with(&problem))?;
            drop(input_lines);

            let was_killed = matches!(exit, ProcessExit::KilledBySignal(_));
            prop_assert!(was_killed, "{exit:?}");
            Ok(())
        })?;
    }
}

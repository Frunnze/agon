use std::slice::from_ref;
use std::time::{Duration, Instant};

use orchestration_hub::process_supervisor::ProcessExit;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::select;

use crate::held_folders::to_case_error;
use crate::terminal_support::{
    TERMINAL_CASES, read_to_end, read_until, start_script,
};

const READY_MARK: &str = "ready>";
const LINE_READING_SCRIPT: &str =
    "printf 'ready>'; read line; printf '[%s]' \"$line\"";
const ENTER_KEY: &str = "\r";
const SIGNALS: [&str; 4] = ["HUP", "INT", "KILL", "TERM"];
const STOP_LIMIT: Duration = Duration::from_secs(5);

fn any_typed_text() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9 .,:é✓中]{1,40}"
        .prop_filter("the shell keeps the line whole", |text| {
            text.trim() == text
        })
}

fn exit_by_signal(signal_name: &str) -> Result<ProcessExit, TestCaseError> {
    let script = format!("kill -{signal_name} $$; sleep 5");
    let mut terminal = start_script(&script, &[])?;
    let _output = read_to_end(&mut terminal);
    terminal.process.wait_for_exit().map_err(to_case_error)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(TERMINAL_CASES))]

    #[test]
    fn test_terminal_keyboard_send_keys_property_typed_lines_arrive(
        text in any_typed_text(),
    ) {
        let mut terminal = start_script(LINE_READING_SCRIPT, &[])?;
        read_until(&mut terminal, READY_MARK)?;

        terminal.keyboard.send_keys(&format!("{text}{ENTER_KEY}"))
            .map_err(to_case_error)?;
        let output = read_to_end(&mut terminal);

        prop_assert!(output.contains(&format!("[{text}]")), "{}", output);
    }

    #[test]
    fn test_terminal_keyboard_send_keys_property_pieces_join_into_one_line(
        pieces in vec(any_typed_text(), 1..4),
    ) {
        let mut terminal = start_script(LINE_READING_SCRIPT, &[])?;
        read_until(&mut terminal, READY_MARK)?;

        for piece in &pieces {
            terminal.keyboard.send_keys(piece).map_err(to_case_error)?;
        }
        terminal.keyboard.send_keys(ENTER_KEY).map_err(to_case_error)?;
        let output = read_to_end(&mut terminal);

        let line = pieces.concat();
        prop_assert!(output.contains(&format!("[{line}]")), "{}", output);
    }

    #[test]
    fn test_terminal_keyboard_send_keys_property_keys_go_to_the_program(
        text in any_typed_text(),
        code in 0_u8..100,
    ) {
        let script = format!(
            "printf 'ready>'; read line; \
             [ \"$line\" = \"$1\" ] && exit {code}; exit 101"
        );
        let mut terminal = start_script(&script, from_ref(&text))?;
        read_until(&mut terminal, READY_MARK)?;

        terminal.keyboard.send_keys(&format!("{text}{ENTER_KEY}"))
            .map_err(to_case_error)?;
        let _output = read_to_end(&mut terminal);
        let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;

        let expected = if code == 0 {
            ProcessExit::Succeeded
        } else {
            ProcessExit::FailedWithCode(u32::from(code))
        };
        prop_assert_eq!(exit, expected);
    }

    #[test]
    fn test_terminal_stopper_stop_property_ends_a_waiting_program(
        wait_seconds in 20_u32..60,
    ) {
        let script = format!("printf 'ready>'; sleep {wait_seconds}");
        let mut terminal = start_script(&script, &[])?;
        read_until(&mut terminal, READY_MARK)?;
        let started = Instant::now();

        terminal.stopper.stop().map_err(to_case_error)?;
        let _output = read_to_end(&mut terminal);
        let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;

        prop_assert!(
            matches!(exit, ProcessExit::KilledBySignal(_)),
            "{:?}",
            exit,
        );
        prop_assert!(started.elapsed() < STOP_LIMIT);
    }

    #[test]
    fn test_terminal_stopper_stop_property_stopping_again_is_harmless(
        stop_count in 2_usize..4,
    ) {
        let mut terminal = start_script("printf 'ready>'; sleep 30", &[])?;
        read_until(&mut terminal, READY_MARK)?;

        for _ in 0..stop_count {
            terminal.stopper.stop().map_err(to_case_error)?;
        }
        let _output = read_to_end(&mut terminal);
        let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;

        prop_assert!(
            matches!(exit, ProcessExit::KilledBySignal(_)),
            "{:?}",
            exit,
        );
    }

    #[test]
    fn test_terminal_stopper_stop_property_hangs_up_the_program(
        code in 1_u8..100,
    ) {
        let script = format!(
            "trap 'printf hung; exit {code}' HUP; printf 'ready>'; \
             while :; do sleep 1; done"
        );
        let mut terminal = start_script(&script, &[])?;
        read_until(&mut terminal, READY_MARK)?;

        terminal.stopper.stop().map_err(to_case_error)?;
        let output = read_to_end(&mut terminal);
        let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;

        prop_assert!(output.ends_with("hung"), "{}", output);
        prop_assert_eq!(exit, ProcessExit::FailedWithCode(u32::from(code)));
    }

    #[test]
    fn test_terminal_process_wait_for_exit_property_reports_the_exit_code(
        code in 0_u32..256,
    ) {
        let mut terminal = start_script("exit \"$1\"", &[code.to_string()])?;

        let _output = read_to_end(&mut terminal);
        let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;

        let expected = if code == 0 {
            ProcessExit::Succeeded
        } else {
            ProcessExit::FailedWithCode(code)
        };
        prop_assert_eq!(exit, expected);
    }

    #[test]
    fn test_terminal_process_wait_for_exit_property_names_the_signal(
        first_signal in select(SIGNALS.to_vec()),
        second_signal in select(SIGNALS.to_vec()),
    ) {
        let first_exit = exit_by_signal(first_signal)?;
        let second_exit = exit_by_signal(second_signal)?;

        let (
            ProcessExit::KilledBySignal(first_name),
            ProcessExit::KilledBySignal(second_name),
        ) = (&first_exit, &second_exit)
        else {
            let exits = format!("{first_exit:?} {second_exit:?}");
            return Err(TestCaseError::fail(exits));
        };
        prop_assert!(!first_name.trim().is_empty());
        let is_same_signal = first_signal == second_signal;
        prop_assert_eq!(first_name == second_name, is_same_signal);
    }

    #[test]
    fn test_terminal_process_wait_for_exit_property_output_comes_first(
        text in "[a-zA-Z0-9 ✓]{1,60}",
        code in 0_u32..256,
    ) {
        let script = "printf '%s' \"$1\"; exit \"$2\"";
        let arguments = [text.clone(), code.to_string()];
        let mut terminal = start_script(script, &arguments)?;

        let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;
        let output = read_to_end(&mut terminal);

        prop_assert_eq!(output, text);
        prop_assert!(exit != ProcessExit::Succeeded || code == 0);
    }
}

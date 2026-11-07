use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use orchestration_hub::interactive_terminal::InteractiveTerminal;
use orchestration_hub::process_supervisor::ProcessExit;
use proptest::prelude::*;

use crate::hook_running::to_case_error;
use crate::terminal_support::{
    TERMINAL_CASES, read_to_end, read_until, start_script,
};

const READY_MARK: &str = "ready>";
const WAITING_SCRIPT: &str = "printf 'ready>'; sleep 30";
const LINE_READING_SCRIPT: &str = "printf 'ready>'; read line; exit 7";
const STOP_LIMIT: Duration = Duration::from_secs(5);
const MILLISECONDS_PER_SECOND: f64 = 1000.0;

fn expected_exit(code: u32) -> ProcessExit {
    if code == 0 {
        ProcessExit::Succeeded
    } else {
        ProcessExit::FailedWithCode(code)
    }
}

fn start_waiting_program() -> Result<InteractiveTerminal, TestCaseError> {
    let mut terminal = start_script(WAITING_SCRIPT, &[])?;
    read_until(&mut terminal, READY_MARK)?;
    Ok(terminal)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(TERMINAL_CASES))]

    #[test]
    fn test_terminal_child_share_property_stopper_and_waiter_see_one_child(
        stop_count in 1_usize..3,
    ) {
        let mut terminal = start_waiting_program()?;

        for _ in 0..stop_count {
            terminal.stopper.stop().map_err(to_case_error)?;
        }
        let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;

        let is_killed = matches!(exit, ProcessExit::KilledBySignal(_));
        prop_assert!(is_killed, "{:?}", exit);
    }

    #[test]
    fn test_terminal_child_share_property_terminals_do_not_share(
        stopped_first in any::<bool>(),
    ) {
        let mut stopped = start_waiting_program()?;
        let mut kept = start_script(LINE_READING_SCRIPT, &[])?;
        read_until(&mut kept, READY_MARK)?;

        if stopped_first {
            stopped.stopper.stop().map_err(to_case_error)?;
        }
        kept.keyboard.send_keys("\r").map_err(to_case_error)?;
        let kept_exit = kept.process.wait_for_exit().map_err(to_case_error)?;
        stopped.stopper.stop().map_err(to_case_error)?;
        let stopped_exit =
            stopped.process.wait_for_exit().map_err(to_case_error)?;

        prop_assert_eq!(kept_exit, ProcessExit::FailedWithCode(7));
        let is_killed = matches!(stopped_exit, ProcessExit::KilledBySignal(_));
        prop_assert!(is_killed, "{:?}", stopped_exit);
    }

    #[test]
    fn test_terminal_child_share_property_stopper_passes_the_exit_on(
        code in 0_u32..100,
    ) {
        let mut terminal = start_script("exit \"$1\"", &[code.to_string()])?;
        let _output = read_to_end(&mut terminal);
        thread::sleep(Duration::from_millis(50));

        terminal.stopper.stop().map_err(to_case_error)?;
        let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;

        prop_assert_eq!(exit, expected_exit(code));
    }

    #[test]
    fn test_terminal_child_check_exit_property_repeated_waits_agree(
        code in 0_u32..256,
        wait_count in 2_usize..5,
    ) {
        let mut terminal = start_script("exit \"$1\"", &[code.to_string()])?;

        let mut exits = Vec::new();
        for _ in 0..wait_count {
            let exit =
                terminal.process.wait_for_exit().map_err(to_case_error)?;
            exits.push(exit);
        }

        for exit in exits {
            prop_assert_eq!(exit, expected_exit(code));
        }
    }

    #[test]
    fn test_terminal_child_check_exit_property_waits_until_the_end(
        run_milliseconds in 50_u32..300,
    ) {
        let run_seconds =
            f64::from(run_milliseconds) / MILLISECONDS_PER_SECOND;
        let script = format!("sleep {run_seconds}");
        let started = Instant::now();
        let mut terminal = start_script(&script, &[])?;

        let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;

        let least = Duration::from_millis(u64::from(run_milliseconds));
        prop_assert!(started.elapsed() >= least);
        prop_assert_eq!(exit, ProcessExit::Succeeded);
    }

    #[test]
    fn test_terminal_child_check_exit_property_reports_each_exit_code(
        code in 0_u32..256,
        printed in "[a-z]{0,20}",
    ) {
        let script = "printf '%s' \"$1\"; exit \"$2\"";
        let arguments = [printed, code.to_string()];
        let mut terminal = start_script(script, &arguments)?;

        let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;

        prop_assert_eq!(exit, expected_exit(code));
    }

    #[test]
    fn test_terminal_child_stop_property_stopping_many_times_is_harmless(
        stop_count in 2_usize..5,
    ) {
        let mut terminal = start_waiting_program()?;
        terminal.stopper.stop().map_err(to_case_error)?;
        let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;

        for _ in 1..stop_count {
            terminal.stopper.stop().map_err(to_case_error)?;
        }
        let exit_again =
            terminal.process.wait_for_exit().map_err(to_case_error)?;

        prop_assert_eq!(exit_again, exit);
    }

    #[test]
    fn test_lock_terminal_child_property_waiting_does_not_hold_the_child(
        wait_head_start_milliseconds in 0_u64..100,
    ) {
        let terminal = start_waiting_program()?;
        let InteractiveTerminal { mut stopper, mut process, .. } = terminal;
        let waiter = thread::spawn(move || process.wait_for_exit());
        thread::sleep(Duration::from_millis(wait_head_start_milliseconds));

        let started = Instant::now();
        stopper.stop().map_err(to_case_error)?;
        let stop_time = started.elapsed();
        let joined = waiter.join();

        prop_assert!(stop_time < STOP_LIMIT, "{:?}", stop_time);
        let Ok(Ok(exit)) = joined else {
            return Err(to_case_error("the waiter failed"));
        };
        let is_killed = matches!(exit, ProcessExit::KilledBySignal(_));
        prop_assert!(is_killed, "{:?}", exit);
    }

    #[test]
    fn test_lock_terminal_child_property_waiters_and_stoppers_take_turns(
        stopper_count in 1_usize..4,
    ) {
        let terminal = start_waiting_program()?;
        let InteractiveTerminal { stopper, mut process, .. } = terminal;
        let shared_stopper = Arc::new(Mutex::new(stopper));
        let mut stoppers = Vec::new();
        for _ in 0..stopper_count {
            let stopper = Arc::clone(&shared_stopper);
            stoppers.push(thread::spawn(move || {
                let mut locked = stopper.lock().map_err(|_| "poisoned")?;
                locked.stop().map_err(|_| "stop failed")
            }));
        }

        let exit = process.wait_for_exit().map_err(to_case_error)?;

        for stopping in stoppers {
            let stopped = stopping.join();
            prop_assert!(matches!(stopped, Ok(Ok(()))), "{:?}", stopped);
        }
        let is_killed = matches!(exit, ProcessExit::KilledBySignal(_));
        prop_assert!(is_killed, "{:?}", exit);
    }
}

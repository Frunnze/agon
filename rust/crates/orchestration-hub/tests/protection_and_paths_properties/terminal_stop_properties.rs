use std::os::unix::process::CommandExt;
use std::process::{Child, Command, Stdio};
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
const STOP_LIMIT: Duration = Duration::from_secs(5);
const QUICK_STOP_LIMIT: Duration = Duration::from_millis(150);
const BYSTANDER_PROGRAM: &str = "sleep";
const BYSTANDER_SECONDS: &str = "30";

fn stop_and_finish(
    terminal: &mut InteractiveTerminal,
) -> Result<(ProcessExit, String, Duration), TestCaseError> {
    let started = Instant::now();
    terminal.stopper.stop().map_err(to_case_error)?;
    let output = read_to_end(terminal);
    let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;
    Ok((exit, output, started.elapsed()))
}

fn start_bystander(has_own_group: bool) -> Result<Child, TestCaseError> {
    let mut command = Command::new(BYSTANDER_PROGRAM);
    command.arg(BYSTANDER_SECONDS).stdin(Stdio::null());
    if has_own_group {
        command.process_group(0);
    }
    command.spawn().map_err(to_case_error)
}

fn is_running(bystander: &mut Child) -> Result<bool, TestCaseError> {
    let status = bystander.try_wait().map_err(to_case_error)?;
    Ok(status.is_none())
}

fn end_bystander(mut bystander: Child) -> Result<(), TestCaseError> {
    bystander.kill().map_err(to_case_error)?;
    bystander.wait().map_err(to_case_error)?;
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(TERMINAL_CASES))]

    #[test]
    fn test_stop_program_property_kills_a_program_ignoring_hang_up(
        wait_seconds in 20_u32..40,
    ) {
        let script =
            format!("trap '' HUP; printf 'ready>'; sleep {wait_seconds}");
        let mut terminal = start_script(&script, &[])?;
        read_until(&mut terminal, READY_MARK)?;

        let (exit, _output, elapsed) = stop_and_finish(&mut terminal)?;

        let is_killed = matches!(exit, ProcessExit::KilledBySignal(_));
        prop_assert!(is_killed, "{:?}", exit);
        prop_assert!(elapsed < STOP_LIMIT, "{:?}", elapsed);
    }

    #[test]
    fn test_stop_program_property_ends_children_ignoring_hang_up(
        wait_seconds in 20_u32..40,
        child_count in 1_usize..3,
    ) {
        let child = format!("(trap '' HUP; sleep {wait_seconds}) & ");
        let children = child.repeat(child_count);
        let script = format!("{children}printf 'ready>'; wait");
        let mut terminal = start_script(&script, &[])?;
        read_until(&mut terminal, READY_MARK)?;

        let (_exit, _output, elapsed) = stop_and_finish(&mut terminal)?;

        prop_assert!(elapsed < STOP_LIMIT, "{:?}", elapsed);
    }

    #[test]
    fn test_stop_program_property_lets_a_quick_cleanup_finish(
        cleanup_milliseconds in 0_u32..100,
        code in 1_u8..100,
    ) {
        let cleanup_seconds = f64::from(cleanup_milliseconds) / 1000.0;
        let script = format!(
            "trap 'sleep {cleanup_seconds}; printf cleaned; exit {code}' HUP; \
             printf 'ready>'; while :; do sleep 1; done"
        );
        let mut terminal = start_script(&script, &[])?;
        read_until(&mut terminal, READY_MARK)?;

        let (exit, output, _elapsed) = stop_and_finish(&mut terminal)?;

        prop_assert!(output.ends_with("cleaned"), "{:?}", output);
        prop_assert_eq!(exit, ProcessExit::FailedWithCode(u32::from(code)));
    }

    #[test]
    fn test_terminal_child_stop_property_does_nothing_after_the_exit(
        code in 0_u32..100,
        stop_count in 1_usize..4,
    ) {
        let mut terminal = start_script("exit \"$1\"", &[code.to_string()])?;
        let _output = read_to_end(&mut terminal);
        let exit = terminal.process.wait_for_exit().map_err(to_case_error)?;

        let started = Instant::now();
        for _ in 0..stop_count {
            terminal.stopper.stop().map_err(to_case_error)?;
        }
        let elapsed = started.elapsed();
        let exit_again =
            terminal.process.wait_for_exit().map_err(to_case_error)?;

        prop_assert!(elapsed < QUICK_STOP_LIMIT, "{:?}", elapsed);
        prop_assert_eq!(exit_again, exit);
    }

    #[test]
    fn test_lock_terminal_child_property_racing_the_waiter_never_fails(
        run_milliseconds in 0_u32..40,
        stop_delay_milliseconds in 0_u64..60,
    ) {
        let run_seconds = f64::from(run_milliseconds) / 1000.0;
        let script = format!("sleep {run_seconds}");
        let terminal = start_script(&script, &[])?;
        let InteractiveTerminal { mut stopper, mut process, .. } = terminal;
        let waiter = thread::spawn(move || process.wait_for_exit());

        thread::sleep(Duration::from_millis(stop_delay_milliseconds));
        let stopped = stopper.stop();
        let joined = waiter.join();

        prop_assert!(stopped.is_ok(), "{:?}", stopped);
        let Ok(Ok(exit)) = joined else {
            return Err(to_case_error("the waiter failed"));
        };
        let is_expected = matches!(
            exit,
            ProcessExit::Succeeded | ProcessExit::KilledBySignal(_),
        );
        prop_assert!(is_expected, "{:?}", exit);
    }

    #[test]
    fn test_terminal_child_stop_property_spares_processes_outside_it(
        has_exited_first in any::<bool>(),
        has_own_group in any::<bool>(),
    ) {
        let mut bystander = start_bystander(has_own_group)?;
        let mut terminal = start_script("printf 'ready>'; read line", &[])?;
        read_until(&mut terminal, READY_MARK)?;
        if has_exited_first {
            terminal.keyboard.send_keys("\r").map_err(to_case_error)?;
            let _output = read_to_end(&mut terminal);
            let _exit =
                terminal.process.wait_for_exit().map_err(to_case_error)?;
        }

        let (_exit, _output, _elapsed) = stop_and_finish(&mut terminal)?;
        let is_bystander_running = is_running(&mut bystander)?;
        end_bystander(bystander)?;

        prop_assert!(is_bystander_running);
    }
}

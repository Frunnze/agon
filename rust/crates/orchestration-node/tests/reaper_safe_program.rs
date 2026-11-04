#![cfg(unix)]

use std::path::Path;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;

use nix::sys::wait::{WaitPidFlag, waitpid};
use nix::unistd::Pid;
use orchestration_node::reaper_safe_program::{ProgramOutcome, run_program};
use proptest::prelude::*;

const SHELL_PROGRAM: &str = "/bin/sh";
const REPORTING_SCRIPT: &str =
    "printf '%s' \"$1\"; printf '%s' \"$2\" >&2; exit \"$3\"";
const ANY_CHILD: i32 = -1;

fn run_reporting_script(
    output: &str,
    errors: &str,
    exit_code: i32,
) -> Result<ProgramOutcome, TestCaseError> {
    let arguments = vec![
        "-c".to_string(),
        REPORTING_SCRIPT.to_string(),
        "reporter".to_string(),
        output.to_string(),
        errors.to_string(),
        exit_code.to_string(),
    ];
    run_program(SHELL_PROGRAM, &arguments, Path::new("/"))
        .map_err(|problem| TestCaseError::fail(problem.to_string()))
}

fn start_foreign_reaper(
    is_running: Arc<AtomicBool>,
) -> thread::JoinHandle<()> {
    thread::spawn(move || {
        while is_running.load(Ordering::Relaxed) {
            let reaped =
                waitpid(Pid::from_raw(ANY_CHILD), Some(WaitPidFlag::WNOHANG));
            if reaped.is_err() {
                thread::yield_now();
            }
        }
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(24))]

    #[test]
    fn test_run_program_property_reports_exit_code_and_output(
        output in "[a-zA-Z0-9 ._-]{0,40}",
        errors in "[a-zA-Z0-9 ._-]{0,40}",
        exit_code in 0_i32..120,
    ) {
        let outcome = run_reporting_script(&output, &errors, exit_code)?;

        prop_assert_eq!(outcome.exit_code, exit_code);
        prop_assert_eq!(outcome.output, output);
        prop_assert_eq!(outcome.errors, errors);
    }

    #[test]
    fn test_run_program_property_survives_a_foreign_reaper(
        output in "[a-zA-Z0-9 ._-]{0,40}",
        exit_code in 0_i32..120,
    ) {
        let is_running = Arc::new(AtomicBool::new(true));
        let reaper = start_foreign_reaper(Arc::clone(&is_running));

        let outcome = run_reporting_script(&output, "", exit_code);
        is_running.store(false, Ordering::Relaxed);
        let joined = reaper.join();

        prop_assert!(joined.is_ok());
        let outcome = outcome?;
        prop_assert_eq!(outcome.exit_code, exit_code);
        prop_assert_eq!(outcome.output, output);
    }
}

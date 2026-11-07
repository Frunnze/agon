use std::collections::BTreeMap;
use std::process::Command;
use std::sync::mpsc::{self, RecvTimeoutError};
use std::thread;
use std::time::Duration;

use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::piped_process::{PipedProcess, start_piped_process};
use orchestration_hub::process_supervisor::{ProcessExit, RunningProcess};
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;

use crate::target_folders::fail_with;

pub type CaseOutcome = Result<(), TestCaseError>;

pub const SHELL: &str = "/bin/sh";
pub const SIGNAL_NAMES: [&str; 6] =
    ["HUP", "INT", "TERM", "KILL", "USR1", "USR2"];
const SCRIPT_OPTION: &str = "-c";
const SCRIPT_NAME: &str = "sh";
const TIME_LIMIT: Duration = Duration::from_secs(30);
const KILL_PROGRAM: &str = "/bin/kill";
const PROCESS_EXISTS_SIGNAL: &str = "-0";
const FORCED_KILL_SIGNAL: &str = "-KILL";
const PROCESS_STATUS_PROGRAM: &str = "/bin/ps";

pub fn shell_command(
    script: &str,
    arguments: &[String],
) -> CommandSpecification {
    let mut shell_arguments = vec![
        SCRIPT_OPTION.to_owned(),
        script.to_owned(),
        SCRIPT_NAME.to_owned(),
    ];
    shell_arguments.extend(arguments.iter().cloned());
    CommandSpecification {
        program: SHELL.to_owned(),
        arguments: shell_arguments,
        environment: BTreeMap::new(),
        working_directory: None,
    }
}

pub fn finish_within_time_limit(
    check: impl FnOnce() -> CaseOutcome + Send + 'static,
) -> CaseOutcome {
    let (outcome_sender, outcome_receiver) = mpsc::channel();
    thread::spawn(move || {
        let _waiting_side_is_gone = outcome_sender.send(check());
    });
    match outcome_receiver.recv_timeout(TIME_LIMIT) {
        Ok(outcome) => outcome,
        Err(RecvTimeoutError::Timeout) => {
            Err(TestCaseError::fail("the check ran past its time limit"))
        }
        Err(RecvTimeoutError::Disconnected) => {
            Err(TestCaseError::fail("the check panicked"))
        }
    }
}

pub fn read_every_line(process: &mut RunningProcess) -> Vec<String> {
    let mut lines = Vec::new();
    while let Some(line) = process.output_lines.blocking_recv() {
        lines.push(line);
    }
    lines
}

pub fn read_next_line(
    process: &mut RunningProcess,
) -> Result<String, TestCaseError> {
    process
        .output_lines
        .blocking_recv()
        .ok_or_else(|| TestCaseError::fail("the output ended early"))
}

pub fn start_piped(
    command: &CommandSpecification,
) -> Result<PipedProcess, TestCaseError> {
    start_piped_process(command).map_err(|problem| fail_with(&problem))
}

pub fn run_piped_to_end(
    command: &CommandSpecification,
) -> Result<(Vec<String>, ProcessExit), TestCaseError> {
    let PipedProcess {
        mut process,
        input_lines,
    } = start_piped(command)?;
    drop(input_lines);
    let lines = read_every_line(&mut process);
    let exit = process
        .wait_for_exit()
        .map_err(|problem| fail_with(&problem))?;
    Ok((lines, exit))
}

pub fn is_process_alive(process_id: &str) -> Result<bool, TestCaseError> {
    let status = Command::new(KILL_PROGRAM)
        .args([PROCESS_EXISTS_SIGNAL, process_id])
        .output()
        .map_err(|problem| fail_with(&problem))?
        .status;
    Ok(status.success())
}

pub fn list_survivors(
    process_ids: &[String],
) -> Result<Vec<String>, TestCaseError> {
    let mut survivors = Vec::new();
    for process_id in process_ids {
        if is_process_alive(process_id)? {
            survivors.push(process_id.clone());
        }
    }
    for survivor in &survivors {
        Command::new(KILL_PROGRAM)
            .args([FORCED_KILL_SIGNAL, survivor])
            .output()
            .map_err(|problem| fail_with(&problem))?;
    }
    Ok(survivors)
}

pub fn read_process_group(process_id: &str) -> Result<String, TestCaseError> {
    let output = Command::new(PROCESS_STATUS_PROGRAM)
        .args(["-o", "pgid=", "-p", process_id])
        .output()
        .map_err(|problem| fail_with(&problem))?;
    let listing = String::from_utf8_lossy(&output.stdout);
    Ok(listing.trim().to_owned())
}

pub fn any_signal_name() -> impl Strategy<Value = &'static str> {
    proptest::sample::select(SIGNAL_NAMES.to_vec())
}

pub fn any_printed_word() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9é中😀 '\"$`;&|<>(){}*?=~#%!.,:_-]{0,20}"
}

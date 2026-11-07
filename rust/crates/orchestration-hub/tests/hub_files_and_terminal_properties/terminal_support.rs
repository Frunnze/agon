use std::collections::BTreeMap;
use std::path::PathBuf;
use std::thread;
use std::time::{Duration, Instant};

use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::interactive_terminal::{
    InteractiveTerminal, start_interactive_terminal,
};
use orchestration_hub::terminal_screen::TerminalSize;
use proptest::prelude::*;

pub const TERMINAL_CASES: u32 = 8;

const SHELL: &str = "/bin/sh";
const OUTPUT_LIMIT: Duration = Duration::from_secs(10);
const POLL_PAUSE: Duration = Duration::from_millis(10);
const TERMINAL_SIZE: TerminalSize = TerminalSize {
    columns: 200,
    rows: 30,
};

pub fn shell_command(
    script: &str,
    arguments: &[String],
    environment: BTreeMap<String, String>,
    working_directory: Option<PathBuf>,
) -> CommandSpecification {
    let mut shell_arguments =
        vec!["-c".to_owned(), script.to_owned(), "sh".to_owned()];
    shell_arguments.extend(arguments.iter().cloned());
    CommandSpecification {
        program: SHELL.to_owned(),
        arguments: shell_arguments,
        environment,
        working_directory,
    }
}

pub fn start_script(
    script: &str,
    arguments: &[String],
) -> Result<InteractiveTerminal, TestCaseError> {
    let command = shell_command(script, arguments, BTreeMap::new(), None);
    start_interactive_terminal(&command, TERMINAL_SIZE)
        .map_err(|problem| TestCaseError::fail(problem.to_string()))
}

pub fn start_command(
    command: &CommandSpecification,
) -> Result<InteractiveTerminal, TestCaseError> {
    start_interactive_terminal(command, TERMINAL_SIZE)
        .map_err(|problem| TestCaseError::fail(problem.to_string()))
}

pub fn read_to_end(terminal: &mut InteractiveTerminal) -> String {
    let mut output = String::new();
    while let Some(text) = terminal.output.blocking_recv() {
        output.push_str(&text);
    }
    output
}

pub fn read_until(
    terminal: &mut InteractiveTerminal,
    expected: &str,
) -> Result<String, TestCaseError> {
    let deadline = Instant::now() + OUTPUT_LIMIT;
    let mut output = String::new();
    while !output.contains(expected) {
        if Instant::now() >= deadline {
            let problem = format!("{expected:?} never came, got {output:?}");
            return Err(TestCaseError::fail(problem));
        }
        while let Ok(text) = terminal.output.try_recv() {
            output.push_str(&text);
        }
        thread::sleep(POLL_PAUSE);
    }
    Ok(output)
}

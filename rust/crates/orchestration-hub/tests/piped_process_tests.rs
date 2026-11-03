use std::collections::BTreeMap;
use std::error::Error;
use std::time::Duration;

use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::piped_process::{PipedProcess, start_piped_process};
use orchestration_hub::process_supervisor::{
    ProcessExit, RunningProcess, SupervisorError,
};
use proptest::collection::vec;
use proptest::prelude::*;
use tokio::runtime::Runtime;
use tokio::time::timeout;

type TestResult = Result<(), Box<dyn Error>>;

const SHELL: &str = "/bin/sh";
const OUTPUT_TIMEOUT: Duration = Duration::from_secs(10);
const ANSWER_EACH_LINE: &str =
    "while IFS= read -r line; do printf 'got %s\\n' \"$line\"; done";

fn shell_command(script: &str) -> CommandSpecification {
    CommandSpecification {
        program: SHELL.to_string(),
        arguments: vec!["-c".to_string(), script.to_string()],
        environment: BTreeMap::new(),
        working_directory: None,
    }
}

fn failure(problem: &impl ToString) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

async fn read_all_lines(process: &mut RunningProcess) -> Vec<String> {
    let mut lines = Vec::new();
    while let Ok(Some(line)) =
        timeout(OUTPUT_TIMEOUT, process.output_lines.recv()).await
    {
        lines.push(line);
    }
    lines
}

#[tokio::test]
async fn answers_lines_written_to_its_input() -> TestResult {
    let PipedProcess {
        mut process,
        input_lines,
    } = start_piped_process(&shell_command(ANSWER_EACH_LINE))?;

    input_lines.send("first".to_string())?;
    input_lines.send("second".to_string())?;
    drop(input_lines);
    let lines = read_all_lines(&mut process).await;
    let exit = process.wait_for_exit()?;

    assert_eq!(lines, vec!["got first", "got second"]);
    assert_eq!(exit, ProcessExit::Succeeded);
    Ok(())
}

#[tokio::test]
async fn reports_lines_printed_to_standard_error() -> TestResult {
    let script = "echo printed; echo complained >&2; exit 4";
    let PipedProcess {
        mut process,
        input_lines,
    } = start_piped_process(&shell_command(script))?;

    drop(input_lines);
    let mut lines = read_all_lines(&mut process).await;
    lines.sort();
    let exit = process.wait_for_exit()?;

    assert_eq!(lines, vec!["complained", "printed"]);
    assert_eq!(exit, ProcessExit::FailedWithCode(4));
    Ok(())
}

#[tokio::test]
async fn stops_a_process_that_keeps_waiting_for_input() -> TestResult {
    let PipedProcess {
        mut process,
        input_lines,
    } = start_piped_process(&shell_command("cat; echo never"))?;

    process.stop()?;
    let exit = process.wait_for_exit()?;
    drop(input_lines);

    assert_ne!(exit, ProcessExit::Succeeded);
    Ok(())
}

#[test]
fn reports_a_missing_program() {
    let command = CommandSpecification {
        program: "/definitely/not/a/program".to_string(),
        arguments: Vec::new(),
        environment: BTreeMap::new(),
        working_directory: None,
    };

    let started = start_piped_process(&command);

    let is_start_failure =
        matches!(started, Err(SupervisorError::StartProcess { .. }));
    assert!(is_start_failure);
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(16))]

    #[test]
    fn test_start_piped_process_property_answers_every_line_in_order(
        written_lines in vec("[a-zA-Z0-9 {}\":,._-]{0,60}", 0..8),
    ) {
        let runtime = Runtime::new().map_err(|problem| failure(&problem))?;
        let started = start_piped_process(&shell_command(ANSWER_EACH_LINE));
        let PipedProcess { mut process, input_lines } =
            started.map_err(|problem| failure(&problem))?;

        for line in &written_lines {
            let sent = input_lines.send(line.clone());
            sent.map_err(|problem| failure(&problem))?;
        }
        drop(input_lines);
        let lines = runtime.block_on(read_all_lines(&mut process));

        let mut expected = Vec::new();
        for line in &written_lines {
            expected.push(format!("got {line}"));
        }
        prop_assert_eq!(lines, expected);
    }
}

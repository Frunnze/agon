use std::collections::BTreeMap;
use std::process::Command;
use std::time::Duration;

use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::piped_process::{PipedProcess, start_piped_process};
use proptest::prelude::*;
use tokio::runtime::Runtime;
use tokio::time::timeout;

const SHELL: &str = "/bin/sh";
const OUTPUT_TIMEOUT: Duration = Duration::from_secs(10);
const KILL_PROGRAM: &str = "/bin/kill";
const PROCESS_EXISTS_SIGNAL: &str = "-0";

fn failure(problem: &impl ToString) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

fn script_starting_background_processes(count: usize) -> String {
    let mut script = String::new();
    for _ in 0..count {
        script.push_str("sleep 30 & echo $!; ");
    }
    script.push_str("wait");
    script
}

fn shell_command(script: &str) -> CommandSpecification {
    CommandSpecification {
        program: SHELL.to_string(),
        arguments: vec!["-c".to_string(), script.to_string()],
        environment: BTreeMap::new(),
        working_directory: None,
    }
}

fn is_process_alive(process_id: &str) -> Result<bool, TestCaseError> {
    let status = Command::new(KILL_PROGRAM)
        .args([PROCESS_EXISTS_SIGNAL, process_id])
        .status()
        .map_err(|problem| failure(&problem))?;
    Ok(status.success())
}

fn stop_and_list_survivors(
    count: usize,
) -> Result<Vec<String>, TestCaseError> {
    let runtime = Runtime::new().map_err(|problem| failure(&problem))?;
    let script = script_starting_background_processes(count);
    let PipedProcess {
        mut process,
        input_lines,
    } = start_piped_process(&shell_command(&script))
        .map_err(|problem| failure(&problem))?;

    let mut background_process_ids = Vec::new();
    for _ in 0..count {
        let next_line = runtime.block_on(async {
            timeout(OUTPUT_TIMEOUT, process.output_lines.recv()).await
        });
        let line = next_line
            .map_err(|problem| failure(&problem))?
            .ok_or_else(|| failure(&"the shell ended early"))?;
        background_process_ids.push(line.trim().to_string());
    }

    process.stop().map_err(|problem| failure(&problem))?;
    process
        .wait_for_exit()
        .map_err(|problem| failure(&problem))?;
    drop(input_lines);

    let mut survivors = Vec::new();
    for process_id in background_process_ids {
        if is_process_alive(&process_id)? {
            survivors.push(process_id);
        }
    }
    Ok(survivors)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_stop_property_ends_every_process_the_agent_started(
        count in 1_usize..4,
    ) {
        let survivors = stop_and_list_survivors(count)?;

        prop_assert!(survivors.is_empty(), "still running: {survivors:?}");
    }
}

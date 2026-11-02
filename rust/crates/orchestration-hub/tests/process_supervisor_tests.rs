use std::collections::BTreeMap;
use std::error::Error;
use std::time::{Duration, Instant};

use orchestration_core::device::SandboxKind;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_command::build_agent_command;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_output::parse_agent_line;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::process_supervisor::{
    ProcessExit, RunningProcess, SupervisorError, start_process,
};
use orchestration_hub::sandbox::{
    ContainerEngine, ContainerSettings, wrap_in_sandbox,
};
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use proptest::prelude::*;
use tokio::runtime::Runtime;
use tokio::time::timeout;

type TestResult = Result<(), Box<dyn Error>>;

const FIXTURES: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures");
const SYSTEM_PATH: &str = "/usr/bin:/bin";
const SHELL: &str = "/bin/sh";
const OUTPUT_TIMEOUT: Duration = Duration::from_secs(10);
const SESSION: &str = "5f0c3e2a-9b1d-4c7e-8a6f-2d4b1e9c7a30";
const BUILD_FAILURE: &str = concat!(
    "** BUILD FAILED **\n\n",
    "error: Signing for \"App\" requires a development team.",
);
const PRINT_EACH_ARGUMENT: &str =
    "for line in \"$@\"; do printf '%s\\n' \"$line\"; done";

async fn read_all_lines(process: &mut RunningProcess) -> Vec<String> {
    let mut lines = Vec::new();
    while let Ok(Some(line)) =
        timeout(OUTPUT_TIMEOUT, process.output_lines.recv()).await
    {
        lines.push(line);
    }
    lines
}

fn shell_command(script: &str, arguments: &[String]) -> CommandSpecification {
    let mut shell_arguments =
        vec!["-c".to_string(), script.to_string(), "sh".to_string()];
    shell_arguments.extend(arguments.iter().cloned());
    CommandSpecification {
        program: SHELL.to_string(),
        arguments: shell_arguments,
        environment: BTreeMap::new(),
        working_directory: None,
    }
}

fn run_to_end(
    command: &CommandSpecification,
) -> Result<(Vec<String>, ProcessExit), Box<dyn Error>> {
    let runtime = Runtime::new()?;
    let mut process = start_process(command)?;
    let lines = runtime.block_on(read_all_lines(&mut process));
    let exit = process.wait_for_exit()?;
    Ok((lines, exit))
}

fn failure(problem: &dyn Error) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

#[tokio::test]
async fn streams_events_from_a_fake_claude_agent_in_its_workspace()
-> TestResult {
    let workspace = tempfile::tempdir()?;
    let settings = ContainerSettings {
        engine: ContainerEngine::Docker,
        image: "agents/runner".to_string(),
    };
    let agent_command = build_agent_command(
        AgentKind::ClaudeCode,
        "Fix the build",
        None,
        SandboxKind::LocalProcess,
    )?;
    let mounts = WorkspaceMounts {
        task_folder: workspace.path().to_path_buf(),
        git_directories: Vec::new(),
    };
    let mut command = wrap_in_sandbox(
        SandboxKind::LocalProcess,
        &settings,
        &agent_command,
        &mounts,
        &[],
    )?;
    let fake_path = format!("{FIXTURES}/bin:{SYSTEM_PATH}");
    command.environment.insert("PATH".to_string(), fake_path);

    let mut process = start_process(&command)?;
    let lines = read_all_lines(&mut process).await;
    let exit = process.wait_for_exit()?;

    let mut events = Vec::new();
    for line in &lines {
        events.extend(parse_agent_line(AgentKind::ClaudeCode, line));
    }
    let expected = vec![
        AgentEvent::Said("Checking the workspace".into()),
        AgentEvent::SessionStarted(SESSION.into()),
        AgentEvent::Said("I'll build the app first to see the error.".into()),
        AgentEvent::UsedTool("Ran xcodebuild -scheme App".into()),
        AgentEvent::ToolFailed(BUILD_FAILURE.into()),
        AgentEvent::UsedTool(
            "Edited ios/App.xcodeproj/project.pbxproj".into(),
        ),
        AgentEvent::Said(
            "The signing team is set and the build passes now.".into(),
        ),
        AgentEvent::Finished,
    ];
    assert_eq!(events, expected);
    assert_eq!(exit, ProcessExit::Succeeded);
    Ok(())
}

#[tokio::test]
async fn stops_a_long_running_process() -> TestResult {
    let script = format!("{FIXTURES}/long_running_agent.sh");
    let command = CommandSpecification {
        program: SHELL.to_string(),
        arguments: vec![script],
        environment: BTreeMap::new(),
        working_directory: None,
    };

    let mut process = start_process(&command)?;
    let first_line =
        timeout(OUTPUT_TIMEOUT, process.output_lines.recv()).await?;
    let stop_requested_at = Instant::now();
    process.stop()?;
    let remaining_lines = read_all_lines(&mut process).await;
    let exit = process.wait_for_exit()?;

    assert_eq!(first_line.as_deref(), Some("started"));
    assert!(stop_requested_at.elapsed() < OUTPUT_TIMEOUT);
    assert_eq!(remaining_lines, Vec::<String>::new());
    assert!(matches!(exit, ProcessExit::KilledBySignal(_)));
    Ok(())
}

#[tokio::test]
async fn runs_in_its_working_directory_with_its_environment() -> TestResult {
    let workspace = tempfile::tempdir()?;
    let mut command =
        shell_command("pwd -P; printf '%s\\n' \"$GREETING\"", &[]);
    command.working_directory = Some(workspace.path().to_path_buf());
    command
        .environment
        .insert("GREETING".to_string(), "hello there".to_string());

    let mut process = start_process(&command)?;
    let lines = read_all_lines(&mut process).await;
    process.wait_for_exit()?;

    let real_workspace = workspace.path().canonicalize()?;
    let expected = vec![
        real_workspace.display().to_string(),
        "hello there".to_string(),
    ];
    assert_eq!(lines, expected);
    Ok(())
}

#[test]
fn reports_a_program_that_cannot_start() {
    let command = CommandSpecification {
        program: "orchestration-hub-missing-program".to_string(),
        arguments: Vec::new(),
        environment: BTreeMap::new(),
        working_directory: None,
    };

    let started = start_process(&command);

    assert!(matches!(started, Err(SupervisorError::StartProcess { .. })));
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(8))]

    #[test]
    fn test_start_process_property_streams_printed_lines_unchanged(
        printed in proptest::collection::vec("[a-zA-Z0-9 ,.:_-]{0,40}", 1..4),
    ) {
        let command = shell_command(PRINT_EACH_ARGUMENT, &printed);

        let (lines, exit) =
            run_to_end(&command).map_err(|problem| failure(&*problem))?;

        prop_assert_eq!(lines, printed);
        prop_assert_eq!(exit, ProcessExit::Succeeded);
    }

    #[test]
    fn test_wait_for_exit_property_reports_the_exit_code(code in 0_u32..256) {
        let command = shell_command("exit \"$1\"", &[code.to_string()]);

        let (_lines, exit) =
            run_to_end(&command).map_err(|problem| failure(&*problem))?;

        let expected = if code == 0 {
            ProcessExit::Succeeded
        } else {
            ProcessExit::FailedWithCode(code)
        };
        prop_assert_eq!(exit, expected);
    }

    #[test]
    fn test_stop_property_is_harmless_after_the_process_exits(
        code in 0_u32..256,
    ) {
        let command = shell_command("exit \"$1\"", &[code.to_string()]);
        let runtime = Runtime::new().map_err(|problem| failure(&problem))?;
        let mut process =
            start_process(&command).map_err(|problem| failure(&problem))?;
        runtime.block_on(read_all_lines(&mut process));
        let first_exit =
            process.wait_for_exit().map_err(|problem| failure(&problem))?;

        let stopped = process.stop();
        let second_exit =
            process.wait_for_exit().map_err(|problem| failure(&problem))?;

        prop_assert!(stopped.is_ok());
        prop_assert_eq!(first_exit, second_exit);
    }
}

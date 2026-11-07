use std::collections::BTreeMap;
use std::fs;
use std::thread;
use std::time::{Duration, Instant};

use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::process_supervisor::{
    ProcessExit, RunningProcess, SupervisorError, start_process,
};
use proptest::collection::{btree_map, vec};
use proptest::prelude::*;

use crate::process_support::{
    CaseOutcome, any_printed_word, finish_within_time_limit, read_every_line,
    read_next_line, run_piped_to_end, shell_command,
};
use crate::target_folders::{create_target_folder, fail_with};

const PROCESS_CASES: u32 = 6;
const PRINT_EACH_ARGUMENT: &str =
    "for argument in \"$@\"; do printf '%s\\n' \"$argument\"; done";
const PRINT_EACH_VARIABLE: &str =
    "for name in \"$@\"; do printf '%s\\n' \"$(printenv \"$name\")\"; done";
const PRINT_WORKING_DIRECTORY: &str = "pwd -P";
const PRINT_PLACE_AND_ARGUMENTS: &str =
    "pwd -P; for argument in \"$@\"; do printf '%s\\n' \"$argument\"; done";
const WAIT_AFTER_GREETING: &str = "echo started; sleep 30";
const INHERITED_VARIABLE: &str = "PATH";
const STOP_TIME_LIMIT: Duration = Duration::from_secs(5);
const EXIT_SETTLING_TIME: Duration = Duration::from_millis(300);

fn start_terminal(
    command: &CommandSpecification,
) -> Result<RunningProcess, TestCaseError> {
    start_process(command).map_err(|problem| fail_with(&problem))
}

fn run_terminal_to_end(
    command: &CommandSpecification,
) -> Result<(Vec<String>, ProcessExit), TestCaseError> {
    let mut process = start_terminal(command)?;
    let lines = read_every_line(&mut process);
    let exit = process
        .wait_for_exit()
        .map_err(|problem| fail_with(&problem))?;
    Ok((lines, exit))
}

fn any_folder_name() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9é中 _.-]{1,16}"
        .prop_filter("a plain folder name", |name| name != "." && name != "..")
}

fn any_variables() -> impl Strategy<Value = BTreeMap<String, String>> {
    btree_map(
        "AGON_TEST_[A-Z0-9_]{1,10}",
        "[a-zA-Z0-9é /:=._-]{0,20}",
        0..5,
    )
}

fn stop_a_waiting_process() -> Result<ProcessExit, TestCaseError> {
    let mut process =
        start_terminal(&shell_command(WAIT_AFTER_GREETING, &[]))?;
    prop_assert_eq!(read_next_line(&mut process)?, "started");

    let stop_requested_at = Instant::now();
    process.stop().map_err(|problem| fail_with(&problem))?;
    let exit = process
        .wait_for_exit()
        .map_err(|problem| fail_with(&problem))?;

    prop_assert!(stop_requested_at.elapsed() < STOP_TIME_LIMIT);
    Ok(exit)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROCESS_CASES))]

    #[test]
    fn test_start_process_property_runs_in_its_working_directory(
        folder_name in any_folder_name(),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let root = create_target_folder()?;
            let folder = root.path().join(&folder_name);
            fs::create_dir_all(&folder)
                .map_err(|problem| fail_with(&problem))?;
            let mut command = shell_command(PRINT_WORKING_DIRECTORY, &[]);
            command.working_directory = Some(folder.clone());

            let (lines, exit) = run_terminal_to_end(&command)?;

            let real_folder =
                folder.canonicalize().map_err(|problem| fail_with(&problem))?;
            prop_assert_eq!(lines, vec![real_folder.display().to_string()]);
            prop_assert_eq!(exit, ProcessExit::Succeeded);
            Ok(())
        })?;
    }

    #[test]
    fn test_start_process_property_refuses_a_missing_working_directory(
        missing_name in "[a-z0-9]{1,12}",
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let root = create_target_folder()?;
            let mut command = shell_command(PRINT_WORKING_DIRECTORY, &[]);
            command.working_directory = Some(root.path().join(missing_name));

            match start_process(&command) {
                Err(SupervisorError::StartProcess { .. }) => Ok(()),
                Err(problem) => Err(fail_with(&problem)),
                Ok(mut process) => {
                    let lines = read_every_line(&mut process);
                    let place = format!("it ran in {lines:?}");
                    Err(TestCaseError::fail(place))
                }
            }
        })?;
    }

    #[test]
    fn test_build_terminal_command_property_passes_arguments_unchanged(
        arguments in vec(any_printed_word(), 0..6),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let command = shell_command(PRINT_EACH_ARGUMENT, &arguments);

            let (lines, exit) = run_terminal_to_end(&command)?;

            prop_assert_eq!(lines, arguments);
            prop_assert_eq!(exit, ProcessExit::Succeeded);
            Ok(())
        })?;
    }

    #[test]
    fn test_build_terminal_command_property_sets_every_variable(
        variables in any_variables(),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let names: Vec<String> = variables.keys().cloned().collect();
            let mut command = shell_command(PRINT_EACH_VARIABLE, &names);
            command.environment.clone_from(&variables);

            let (lines, _exit) = run_terminal_to_end(&command)?;

            let values: Vec<String> = variables.values().cloned().collect();
            prop_assert_eq!(lines, values);
            Ok(())
        })?;
    }

    #[test]
    fn test_build_terminal_command_property_keeps_inherited_variables(
        variables in any_variables(),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let names = vec![INHERITED_VARIABLE.to_owned()];
            let mut command = shell_command(PRINT_EACH_VARIABLE, &names);
            command.environment = variables;

            let (lines, _exit) = run_terminal_to_end(&command)?;

            let inherited = std::env::var(INHERITED_VARIABLE)
                .map_err(|problem| fail_with(&problem))?;
            prop_assert_eq!(lines, vec![inherited]);
            Ok(())
        })?;
    }

    #[test]
    fn test_start_piped_process_property_agrees_with_the_terminal_process(
        arguments in vec(any_printed_word(), 0..4),
        code in 0_u32..256,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let root = create_target_folder()?;
            let script = format!("{PRINT_PLACE_AND_ARGUMENTS}; exit {code}");
            let mut command = shell_command(&script, &arguments);
            command.working_directory = Some(root.path().to_path_buf());

            let terminal_run = run_terminal_to_end(&command)?;
            let piped_run = run_piped_to_end(&command)?;

            prop_assert_eq!(terminal_run, piped_run);
            Ok(())
        })?;
    }

    #[test]
    fn test_stop_property_ends_a_waiting_terminal_process(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let exit = stop_a_waiting_process()?;

            let was_killed = matches!(exit, ProcessExit::KilledBySignal(_));
            prop_assert!(was_killed, "{exit:?}");
            Ok(())
        })?;
    }

    #[test]
    fn test_stop_property_is_harmless_once_the_process_ended(
        code in 0_u32..256,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let command = shell_command(&format!("exit {code}"), &[]);
            let mut process = start_terminal(&command)?;
            read_every_line(&mut process);
            thread::sleep(EXIT_SETTLING_TIME);

            let stopped = process.stop();
            let exit = process
                .wait_for_exit()
                .map_err(|problem| fail_with(&problem))?;

            prop_assert!(stopped.is_ok(), "{stopped:?}");
            let expected = if code == 0 {
                ProcessExit::Succeeded
            } else {
                ProcessExit::FailedWithCode(code)
            };
            prop_assert_eq!(exit, expected);
            Ok(())
        })?;
    }

    #[test]
    fn test_stop_property_can_be_repeated(stop_count in 1_usize..4) {
        finish_within_time_limit(move || -> CaseOutcome {
            let command = shell_command(WAIT_AFTER_GREETING, &[]);
            let mut process = start_terminal(&command)?;
            read_next_line(&mut process)?;

            for _ in 0..stop_count {
                process.stop().map_err(|problem| fail_with(&problem))?;
            }
            let exit = process
                .wait_for_exit()
                .map_err(|problem| fail_with(&problem))?;
            let stopped_again = process.stop();

            prop_assert!(stopped_again.is_ok());
            prop_assert_ne!(exit, ProcessExit::Succeeded);
            Ok(())
        })?;
    }

    #[test]
    fn test_wait_for_exit_property_repeated_waits_agree(
        code in 0_u32..256,
        wait_count in 2_usize..5,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let command = shell_command(&format!("exit {code}"), &[]);
            let mut process = start_terminal(&command)?;
            read_every_line(&mut process);

            let mut exits = Vec::new();
            for _ in 0..wait_count {
                let exit = process
                    .wait_for_exit()
                    .map_err(|problem| fail_with(&problem))?;
                exits.push(exit);
            }

            let first_exit = exits[0].clone();
            prop_assert!(exits.iter().all(|exit| *exit == first_exit));
            Ok(())
        })?;
    }

    #[test]
    fn test_wait_for_exit_property_reports_a_stopped_process_as_killed(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let exit = stop_a_waiting_process()?;

            prop_assert_ne!(&exit, &ProcessExit::Succeeded);
            let is_code = matches!(exit, ProcessExit::FailedWithCode(_));
            prop_assert!(!is_code, "{exit:?}");
            Ok(())
        })?;
    }
}

use std::fs;
use std::thread;
use std::time::Duration;

use orchestration_hub::piped_process::{PipedProcess, start_piped_process};
use orchestration_hub::process_supervisor::{ProcessExit, SupervisorError};
use proptest::collection::{btree_map, vec};
use proptest::prelude::*;

use crate::process_support::{
    CaseOutcome, any_printed_word, finish_within_time_limit, read_every_line,
    run_piped_to_end, shell_command, start_piped,
};
use crate::target_folders::{create_target_folder, fail_with};

const PROCESS_CASES: u32 = 6;
const PRINT_EACH_ARGUMENT: &str =
    "for argument in \"$@\"; do printf '%s\\n' \"$argument\"; done";
const PRINT_EACH_VARIABLE: &str =
    "for name in \"$@\"; do printf '%s\\n' \"$(printenv \"$name\")\"; done";
const PRINT_WORKING_DIRECTORY: &str = "pwd -P";
const COPY_INPUT: &str = "/bin/cat";
const EXIT_SETTLING_TIME: Duration = Duration::from_millis(300);

fn any_input_line() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9é中😀 {}\":,._\\t-]{0,40}"
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROCESS_CASES))]

    #[test]
    fn test_start_piped_process_property_refuses_a_missing_folder(
        missing_name in "[a-z0-9]{1,12}",
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let root = create_target_folder()?;
            let mut command = shell_command(PRINT_WORKING_DIRECTORY, &[]);
            command.working_directory = Some(root.path().join(missing_name));

            let started = start_piped_process(&command);

            let is_refused =
                matches!(started, Err(SupervisorError::StartProcess { .. }));
            prop_assert!(is_refused);
            Ok(())
        })?;
    }

    #[test]
    fn test_start_piped_process_property_merges_both_output_streams(
        printed in vec("[a-z0-9 ]{0,12}", 0..4),
        complained in vec("[A-Z0-9 ]{0,12}", 0..4),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut arguments = vec![printed.len().to_string()];
            arguments.extend(printed.iter().cloned());
            arguments.extend(complained.iter().cloned());
            let script = "count=$1; shift; i=0; for word in \"$@\"; do \
                if [ $i -lt $count ]; then printf '%s\\n' \"$word\"; \
                else printf '%s\\n' \"$word\" >&2; fi; i=$((i+1)); done";

            let (mut lines, _exit) =
                run_piped_to_end(&shell_command(script, &arguments))?;

            let mut expected = printed;
            expected.extend(complained);
            lines.sort();
            expected.sort();
            prop_assert_eq!(lines, expected);
            Ok(())
        })?;
    }

    #[test]
    fn test_build_piped_command_property_passes_arguments_unchanged(
        arguments in vec(any_printed_word(), 0..6),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let command = shell_command(PRINT_EACH_ARGUMENT, &arguments);

            let (lines, exit) = run_piped_to_end(&command)?;

            prop_assert_eq!(lines, arguments);
            prop_assert_eq!(exit, ProcessExit::Succeeded);
            Ok(())
        })?;
    }

    #[test]
    fn test_build_piped_command_property_sets_every_variable(
        variables in btree_map(
            "AGON_TEST_[A-Z0-9_]{1,10}",
            "[a-zA-Z0-9é /:=._-]{0,20}",
            0..5,
        ),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let names: Vec<String> = variables.keys().cloned().collect();
            let mut command = shell_command(PRINT_EACH_VARIABLE, &names);
            command.environment.clone_from(&variables);

            let (lines, _exit) = run_piped_to_end(&command)?;

            let values: Vec<String> = variables.values().cloned().collect();
            prop_assert_eq!(lines, values);
            Ok(())
        })?;
    }

    #[test]
    fn test_build_piped_command_property_runs_in_its_working_directory(
        folder_name in "[a-zA-Z0-9é中 _-]{1,16}",
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let root = create_target_folder()?;
            let folder = root.path().join(&folder_name);
            fs::create_dir_all(&folder)
                .map_err(|problem| fail_with(&problem))?;
            let mut command = shell_command(PRINT_WORKING_DIRECTORY, &[]);
            command.working_directory = Some(folder.clone());

            let (lines, _exit) = run_piped_to_end(&command)?;

            let real_folder =
                folder.canonicalize().map_err(|problem| fail_with(&problem))?;
            prop_assert_eq!(lines, vec![real_folder.display().to_string()]);
            Ok(())
        })?;
    }

    #[test]
    fn test_forward_input_lines_property_every_line_arrives_unchanged(
        written_lines in vec(any_input_line(), 0..8),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut command = shell_command("", &[]);
            command.program = COPY_INPUT.to_owned();
            command.arguments = Vec::new();
            let PipedProcess { mut process, input_lines } =
                start_piped(&command)?;

            for line in &written_lines {
                input_lines
                    .send(line.clone())
                    .map_err(|problem| fail_with(&problem))?;
            }
            drop(input_lines);
            let lines = read_every_line(&mut process);
            let exit = process
                .wait_for_exit()
                .map_err(|problem| fail_with(&problem))?;

            prop_assert_eq!(lines, written_lines);
            prop_assert_eq!(exit, ProcessExit::Succeeded);
            Ok(())
        })?;
    }

    #[test]
    fn test_forward_input_lines_property_closing_input_ends_the_reader(
        line_count in 0_usize..4,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let script = "count=0; while IFS= read -r line; do \
                count=$((count+1)); done; echo \"$count\"";
            let PipedProcess { mut process, input_lines } =
                start_piped(&shell_command(script, &[]))?;

            for _ in 0..line_count {
                input_lines
                    .send(String::new())
                    .map_err(|problem| fail_with(&problem))?;
            }
            drop(input_lines);
            let lines = read_every_line(&mut process);

            prop_assert_eq!(lines, vec![line_count.to_string()]);
            Ok(())
        })?;
    }

    #[test]
    fn test_forward_input_lines_property_writing_after_the_end_is_harmless(
        late_lines in vec(any_input_line(), 1..6),
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let PipedProcess { mut process, input_lines } =
                start_piped(&shell_command("exit 0", &[]))?;
            read_every_line(&mut process);
            thread::sleep(EXIT_SETTLING_TIME);

            for line in late_lines {
                let _sending_may_fail_once_input_closed =
                    input_lines.send(line);
            }
            let exit = process
                .wait_for_exit()
                .map_err(|problem| fail_with(&problem))?;

            prop_assert_eq!(exit, ProcessExit::Succeeded);
            Ok(())
        })?;
    }

}

use std::fs;
use std::os::unix::fs::symlink;
use std::path::Path;

use orchestration_hub::interactive_terminal::start_interactive_terminal;
use orchestration_hub::process_supervisor::{SupervisorError, start_process};
use orchestration_hub::terminal_screen::TerminalSize;
use proptest::prelude::*;

use crate::process_support::{
    CaseOutcome, finish_within_time_limit, read_every_line, shell_command,
};
use crate::target_folders::{create_target_folder, fail_with};

const FOLDER_CASES: u32 = 6;
const PRINT_WORKING_DIRECTORY: &str = "pwd -P";
const TERMINAL_SIZE: TerminalSize = TerminalSize {
    columns: 80,
    rows: 24,
};

fn refuses_to_start_in(folder: &Path) -> CaseOutcome {
    let mut command = shell_command(PRINT_WORKING_DIRECTORY, &[]);
    command.working_directory = Some(folder.to_path_buf());
    let shown_folder = folder.display().to_string();

    let piped_by_terminal = start_process(&command);
    let interactive = start_interactive_terminal(&command, TERMINAL_SIZE);

    let Err(SupervisorError::StartProcess { reason, .. }) = piped_by_terminal
    else {
        return Err(TestCaseError::fail("the terminal process started"));
    };
    prop_assert!(reason.contains(&shown_folder), "{reason}");
    let is_refused =
        matches!(interactive, Err(SupervisorError::StartProcess { .. }));
    prop_assert!(is_refused, "the interactive terminal started");
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FOLDER_CASES))]

    #[test]
    fn test_ensure_working_folder_exists_property_refuses_missing_folders(
        missing_name in "[a-zA-Z0-9é _-]{1,12}",
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let root = create_target_folder()?;

            refuses_to_start_in(&root.path().join(missing_name))
        })?;
    }

    #[test]
    fn test_ensure_working_folder_exists_property_refuses_a_file(
        file_name in "[a-zA-Z0-9é _-]{1,12}",
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let root = create_target_folder()?;
            let file = root.path().join(file_name);
            fs::write(&file, "not a folder")
                .map_err(|problem| fail_with(&problem))?;

            refuses_to_start_in(&file)
        })?;
    }

    #[test]
    fn test_ensure_working_folder_exists_property_follows_folder_links(
        folder_name in "[a-zA-Z0-9é _-]{1,12}",
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let root = create_target_folder()?;
            let folder = root.path().join(&folder_name);
            fs::create_dir_all(&folder)
                .map_err(|problem| fail_with(&problem))?;
            let link = root.path().join(format!("link to {folder_name}"));
            symlink(&folder, &link).map_err(|problem| fail_with(&problem))?;
            let mut command = shell_command(PRINT_WORKING_DIRECTORY, &[]);
            command.working_directory = Some(link);

            let mut process = start_process(&command)
                .map_err(|problem| fail_with(&problem))?;
            let lines = read_every_line(&mut process);

            let real_folder =
                folder.canonicalize().map_err(|problem| fail_with(&problem))?;
            prop_assert_eq!(lines, vec![real_folder.display().to_string()]);
            Ok(())
        })?;
    }
}

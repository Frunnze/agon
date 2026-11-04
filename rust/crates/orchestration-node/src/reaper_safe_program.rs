use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};

use uuid::Uuid;

const SHELL_PROGRAM: &str = "/bin/sh";
const WRAPPER_SCRIPT: &str = "\"$0\" \"$@\" >\"$AGON_OUTPUT_FILE\" \
    2>\"$AGON_ERRORS_FILE\"; printf '%s' \"$?\" >\"$AGON_STATUS_FILE.part\"; \
    mv \"$AGON_STATUS_FILE.part\" \"$AGON_STATUS_FILE\"";
const OUTPUT_FILE_VARIABLE: &str = "AGON_OUTPUT_FILE";
const ERRORS_FILE_VARIABLE: &str = "AGON_ERRORS_FILE";
const STATUS_FILE_VARIABLE: &str = "AGON_STATUS_FILE";
const OUTCOME_FOLDER_PREFIX: &str = "agon-program-";
const OUTPUT_FILE_NAME: &str = "output";
const ERRORS_FILE_NAME: &str = "errors";
const STATUS_FILE_NAME: &str = "status";
const CHILD_ALREADY_REAPED_CODE: i32 = 10;
const STATUS_CHECK_INTERVAL: Duration = Duration::from_millis(10);
const STATUS_WAIT_LIMIT: Duration = Duration::from_secs(120);

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProgramOutcome {
    pub exit_code: i32,
    pub output: String,
    pub errors: String,
}

impl ProgramOutcome {
    #[must_use]
    pub const fn has_succeeded(&self) -> bool {
        self.exit_code == 0
    }
}

struct OutcomeFiles {
    folder: PathBuf,
    output: PathBuf,
    errors: PathBuf,
    status: PathBuf,
}

pub fn run_program(
    program: &str,
    arguments: &[String],
    working_folder: &Path,
) -> io::Result<ProgramOutcome> {
    let files = create_outcome_files()?;
    let outcome =
        run_with_outcome_files(program, arguments, working_folder, &files);
    fs::remove_dir_all(&files.folder)?;
    outcome
}

fn run_with_outcome_files(
    program: &str,
    arguments: &[String],
    working_folder: &Path,
    files: &OutcomeFiles,
) -> io::Result<ProgramOutcome> {
    let mut child = Command::new(SHELL_PROGRAM)
        .arg("-c")
        .arg(WRAPPER_SCRIPT)
        .arg(program)
        .args(arguments)
        .env(OUTPUT_FILE_VARIABLE, &files.output)
        .env(ERRORS_FILE_VARIABLE, &files.errors)
        .env(STATUS_FILE_VARIABLE, &files.status)
        .current_dir(working_folder)
        .spawn()?;
    match child.wait() {
        Ok(_) => {}
        Err(problem) if is_child_already_reaped(&problem) => {}
        Err(problem) => return Err(problem),
    }

    let exit_code = wait_for_exit_code(&files.status)?;
    Ok(ProgramOutcome {
        exit_code,
        output: fs::read_to_string(&files.output)?,
        errors: fs::read_to_string(&files.errors)?,
    })
}

fn create_outcome_files() -> io::Result<OutcomeFiles> {
    let folder_name = format!("{OUTCOME_FOLDER_PREFIX}{}", Uuid::new_v4());
    let folder = std::env::temp_dir().join(folder_name);
    fs::create_dir(&folder)?;
    Ok(OutcomeFiles {
        output: folder.join(OUTPUT_FILE_NAME),
        errors: folder.join(ERRORS_FILE_NAME),
        status: folder.join(STATUS_FILE_NAME),
        folder,
    })
}

fn is_child_already_reaped(problem: &io::Error) -> bool {
    problem.raw_os_error() == Some(CHILD_ALREADY_REAPED_CODE)
}

fn wait_for_exit_code(status_file: &Path) -> io::Result<i32> {
    let deadline = Instant::now() + STATUS_WAIT_LIMIT;
    while !status_file.exists() {
        if Instant::now() > deadline {
            return Err(io::Error::other(
                "the program never reported its end",
            ));
        }
        thread::sleep(STATUS_CHECK_INTERVAL);
    }
    let status_text = fs::read_to_string(status_file)?;
    status_text
        .trim()
        .parse::<i32>()
        .map_err(|problem| io::Error::other(problem.to_string()))
}

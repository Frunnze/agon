use std::io::{BufRead, BufReader, Read};
use std::path::Path;
use std::thread;

use portable_pty::{
    Child, CommandBuilder, ExitStatus, PtySize, native_pty_system,
};
use thiserror::Error;
use tokio::sync::mpsc::{
    UnboundedReceiver, UnboundedSender, unbounded_channel,
};

use crate::command_specification::CommandSpecification;

const LINE_FEED: u8 = b'\n';
const CARRIAGE_RETURN: char = '\r';
const MISSING_FOLDER_REASON: &str = "the working folder does not exist";

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ProcessExit {
    Succeeded,
    FailedWithCode(u32),
    KilledBySignal(String),
}

#[derive(Debug, Error)]
pub enum SupervisorError {
    #[error("could not open a terminal: {0}")]
    OpenTerminal(String),
    #[error("could not connect to the input and output of the process")]
    OpenPipes,
    #[error("could not read the terminal output: {0}")]
    ReadOutput(String),
    #[error("could not start {program}: {reason}")]
    StartProcess { program: String, reason: String },
    #[error("could not stop the process: {0}")]
    StopProcess(#[source] std::io::Error),
    #[error("could not wait for the process: {0}")]
    WaitForProcess(#[source] std::io::Error),
    #[error("could not type into the terminal: {0}")]
    WriteInput(#[source] std::io::Error),
}

#[derive(Debug)]
pub struct RunningProcess {
    pub output_lines: UnboundedReceiver<String>,
    child: Box<dyn Child + Send + Sync>,
    has_ended: bool,
}

pub fn start_process(
    command: &CommandSpecification,
) -> Result<RunningProcess, SupervisorError> {
    let terminal = native_pty_system().openpty(PtySize::default()).map_err(
        |problem| SupervisorError::OpenTerminal(problem.to_string()),
    )?;
    let reader = terminal
        .master
        .try_clone_reader()
        .map_err(|problem| SupervisorError::ReadOutput(problem.to_string()))?;
    let child = terminal
        .slave
        .spawn_command(build_terminal_command(command)?)
        .map_err(|problem| SupervisorError::StartProcess {
            program: command.program.clone(),
            reason: problem.to_string(),
        })?;

    let (sender, output_lines) = unbounded_channel();
    thread::spawn(move || forward_output_lines(reader, &sender));
    Ok(RunningProcess::new(output_lines, child))
}

impl RunningProcess {
    pub(crate) fn new(
        output_lines: UnboundedReceiver<String>,
        child: Box<dyn Child + Send + Sync>,
    ) -> Self {
        Self {
            output_lines,
            child,
            has_ended: false,
        }
    }

    pub fn stop(&mut self) -> Result<(), SupervisorError> {
        if self.has_ended {
            return Ok(());
        }
        self.child.kill().map_err(SupervisorError::StopProcess)?;
        self.has_ended = true;
        Ok(())
    }

    pub fn wait_for_exit(&mut self) -> Result<ProcessExit, SupervisorError> {
        let status =
            self.child.wait().map_err(SupervisorError::WaitForProcess)?;
        self.has_ended = true;
        Ok(describe_exit_status(&status))
    }
}

pub(crate) fn build_terminal_command(
    command: &CommandSpecification,
) -> Result<CommandBuilder, SupervisorError> {
    let mut builder = CommandBuilder::new(&command.program);
    builder.args(&command.arguments);
    for (name, value) in &command.environment {
        builder.env(name, value);
    }
    if let Some(directory) = &command.working_directory {
        ensure_working_folder_exists(&command.program, directory)?;
        builder.cwd(directory);
    }
    Ok(builder)
}

fn ensure_working_folder_exists(
    program: &str,
    directory: &Path,
) -> Result<(), SupervisorError> {
    if directory.is_dir() {
        return Ok(());
    }
    Err(SupervisorError::StartProcess {
        program: program.to_owned(),
        reason: format!("{MISSING_FOLDER_REASON}: {}", directory.display()),
    })
}

pub(crate) fn forward_output_lines(
    reader: Box<dyn Read + Send>,
    sender: &UnboundedSender<String>,
) {
    let mut buffered_reader = BufReader::new(reader);
    loop {
        let mut line_bytes = Vec::new();
        let Ok(read_count) =
            buffered_reader.read_until(LINE_FEED, &mut line_bytes)
        else {
            return;
        };
        if read_count == 0 {
            return;
        }

        let line = String::from_utf8_lossy(&line_bytes);
        let without_ending = line
            .strip_suffix(char::from(LINE_FEED))
            .unwrap_or(&line)
            .trim_end_matches(CARRIAGE_RETURN);
        if sender.send(without_ending.to_string()).is_err() {
            return;
        }
    }
}

pub(crate) fn describe_exit_status(status: &ExitStatus) -> ProcessExit {
    if let Some(signal) = status.signal() {
        return ProcessExit::KilledBySignal(signal.to_string());
    }
    if status.success() {
        return ProcessExit::Succeeded;
    }
    ProcessExit::FailedWithCode(status.exit_code())
}

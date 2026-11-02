use std::fmt;
use std::io::{Read, Write};
use std::thread;

use portable_pty::{Child, ChildKiller, PtySize, native_pty_system};
use tokio::sync::mpsc::{
    UnboundedReceiver, UnboundedSender, unbounded_channel,
};

use crate::command_specification::CommandSpecification;
use crate::process_supervisor::{
    ProcessExit, SupervisorError, build_terminal_command, describe_exit_status,
};
use crate::terminal_screen::TerminalSize;
use crate::utf8_chunks::drain_complete_text;

const READ_BUFFER_LENGTH: usize = 4096;

#[derive(Debug)]
pub struct InteractiveTerminal {
    pub output: UnboundedReceiver<String>,
    pub keyboard: TerminalKeyboard,
    pub stopper: TerminalStopper,
    pub process: TerminalProcess,
}

pub struct TerminalKeyboard {
    writer: Box<dyn Write + Send>,
}

pub struct TerminalStopper {
    killer: Box<dyn ChildKiller + Send + Sync>,
}

pub struct TerminalProcess {
    child: Box<dyn Child + Send + Sync>,
}

pub fn start_interactive_terminal(
    command: &CommandSpecification,
    size: TerminalSize,
) -> Result<InteractiveTerminal, SupervisorError> {
    let terminal_size = PtySize {
        rows: size.rows,
        cols: size.columns,
        pixel_width: 0,
        pixel_height: 0,
    };
    let terminal =
        native_pty_system()
            .openpty(terminal_size)
            .map_err(|problem| {
                SupervisorError::OpenTerminal(problem.to_string())
            })?;
    let reader = terminal
        .master
        .try_clone_reader()
        .map_err(|problem| SupervisorError::ReadOutput(problem.to_string()))?;
    let writer = terminal.master.take_writer().map_err(|problem| {
        SupervisorError::OpenTerminal(problem.to_string())
    })?;
    let child = terminal
        .slave
        .spawn_command(build_terminal_command(command))
        .map_err(|problem| SupervisorError::StartProcess {
            program: command.program.clone(),
            reason: problem.to_string(),
        })?;

    let (sender, output) = unbounded_channel();
    thread::spawn(move || forward_output_text(reader, &sender));
    Ok(InteractiveTerminal {
        output,
        keyboard: TerminalKeyboard { writer },
        stopper: TerminalStopper {
            killer: child.clone_killer(),
        },
        process: TerminalProcess { child },
    })
}

impl TerminalKeyboard {
    pub fn send_keys(&mut self, keys: &str) -> Result<(), SupervisorError> {
        self.writer
            .write_all(keys.as_bytes())
            .map_err(SupervisorError::WriteInput)?;
        self.writer.flush().map_err(SupervisorError::WriteInput)
    }
}

impl TerminalStopper {
    pub fn stop(&mut self) -> Result<(), SupervisorError> {
        self.killer.kill().map_err(SupervisorError::StopProcess)
    }
}

impl TerminalProcess {
    pub fn wait_for_exit(&mut self) -> Result<ProcessExit, SupervisorError> {
        let status =
            self.child.wait().map_err(SupervisorError::WaitForProcess)?;
        Ok(describe_exit_status(&status))
    }
}

impl fmt::Debug for TerminalKeyboard {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("TerminalKeyboard")
            .finish_non_exhaustive()
    }
}

impl fmt::Debug for TerminalStopper {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("TerminalStopper")
            .finish_non_exhaustive()
    }
}

impl fmt::Debug for TerminalProcess {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("TerminalProcess")
            .finish_non_exhaustive()
    }
}

fn forward_output_text(
    mut reader: Box<dyn Read + Send>,
    sender: &UnboundedSender<String>,
) {
    let mut buffer = [0_u8; READ_BUFFER_LENGTH];
    let mut pending = Vec::new();
    loop {
        let Ok(read_count) = reader.read(&mut buffer) else {
            return;
        };
        if read_count == 0 {
            return;
        }

        pending.extend_from_slice(&buffer[..read_count]);
        let text = drain_complete_text(&mut pending);
        if !text.is_empty() && sender.send(text).is_err() {
            return;
        }
    }
}

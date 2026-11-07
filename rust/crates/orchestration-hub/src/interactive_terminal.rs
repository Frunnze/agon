use std::fmt;
use std::io::{Read, Write};
use std::thread;
use std::time::Duration;

use portable_pty::{PtySize, native_pty_system};
use tokio::sync::mpsc::{
    UnboundedReceiver, UnboundedSender, unbounded_channel,
};

use crate::command_specification::CommandSpecification;
use crate::process_supervisor::{
    ProcessExit, SupervisorError, build_terminal_command,
};
use crate::terminal_child::{
    SharedTerminalChild, TerminalChild, lock_terminal_child,
};
use crate::terminal_screen::TerminalSize;
use crate::utf8_chunks::drain_complete_text;

const READ_BUFFER_LENGTH: usize = 4096;
const EXIT_CHECK_PAUSE: Duration = Duration::from_millis(20);

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
    child: SharedTerminalChild,
}

pub struct TerminalProcess {
    child: SharedTerminalChild,
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
        .spawn_command(build_terminal_command(command)?)
        .map_err(|problem| SupervisorError::StartProcess {
            program: command.program.clone(),
            reason: problem.to_string(),
        })?;

    let (sender, output) = unbounded_channel();
    thread::spawn(move || forward_output_text(reader, &sender));
    let shared_child = TerminalChild::share(child);
    Ok(InteractiveTerminal {
        output,
        keyboard: TerminalKeyboard { writer },
        stopper: TerminalStopper {
            child: SharedTerminalChild::clone(&shared_child),
        },
        process: TerminalProcess {
            child: shared_child,
        },
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
        let mut child = lock_terminal_child(&self.child);
        child.stop().map_err(SupervisorError::StopProcess)
    }
}

impl TerminalProcess {
    pub fn wait_for_exit(&mut self) -> Result<ProcessExit, SupervisorError> {
        loop {
            let exit = lock_terminal_child(&self.child)
                .check_exit()
                .map_err(SupervisorError::WaitForProcess)?;
            if let Some(exit) = exit {
                return Ok(exit);
            }
            thread::sleep(EXIT_CHECK_PAUSE);
        }
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
    while let Ok(read_count) = reader.read(&mut buffer)
        && read_count > 0
    {
        pending.extend_from_slice(&buffer[..read_count]);
        let text = drain_complete_text(&mut pending);
        if !text.is_empty() && sender.send(text).is_err() {
            return;
        }
    }

    if !pending.is_empty() {
        let cut_text = String::from_utf8_lossy(&pending).into_owned();
        let _output_is_closed = sender.send(cut_text);
    }
}

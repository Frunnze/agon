use std::io::{self, Write};
use std::process::{ChildStdin, Command, Stdio};
use std::thread;

use tokio::sync::mpsc::{
    UnboundedReceiver, UnboundedSender, unbounded_channel,
};

use portable_pty::Child;

use crate::command_specification::CommandSpecification;
use crate::process_supervisor::{
    RunningProcess, SupervisorError, forward_output_lines,
};

#[derive(Debug)]
pub struct PipedProcess {
    pub process: RunningProcess,
    pub input_lines: UnboundedSender<String>,
}

pub fn start_piped_process(
    command: &CommandSpecification,
) -> Result<PipedProcess, SupervisorError> {
    let mut child =
        build_piped_command(command).spawn().map_err(|problem| {
            SupervisorError::StartProcess {
                program: command.program.clone(),
                reason: problem.to_string(),
            }
        })?;
    let input = child.stdin.take().ok_or(SupervisorError::OpenPipes)?;
    let output = child.stdout.take().ok_or(SupervisorError::OpenPipes)?;
    let errors = child.stderr.take().ok_or(SupervisorError::OpenPipes)?;

    let (output_sender, output_lines) = unbounded_channel();
    let error_sender = output_sender.clone();
    thread::spawn(move || {
        forward_output_lines(Box::new(output), &output_sender);
    });
    thread::spawn(move || {
        forward_output_lines(Box::new(errors), &error_sender);
    });

    let (input_lines, unsent_lines) = unbounded_channel();
    thread::spawn(move || forward_input_lines(unsent_lines, input));
    let supervised =
        supervise_with_its_children(child).map_err(|problem| {
            SupervisorError::StartProcess {
                program: command.program.clone(),
                reason: problem.to_string(),
            }
        })?;
    Ok(PipedProcess {
        process: RunningProcess::new(output_lines, supervised),
        input_lines,
    })
}

fn build_piped_command(command: &CommandSpecification) -> Command {
    let mut builder = Command::new(&command.program);
    builder
        .args(&command.arguments)
        .envs(&command.environment)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    start_in_own_process_group(&mut builder);
    if let Some(directory) = &command.working_directory {
        builder.current_dir(directory);
    }
    builder
}

fn forward_input_lines(
    mut unsent_lines: UnboundedReceiver<String>,
    mut input: ChildStdin,
) {
    while let Some(line) = unsent_lines.blocking_recv() {
        let written = writeln!(input, "{line}").and_then(|()| input.flush());
        if written.is_err() {
            return;
        }
    }
}

#[cfg(unix)]
fn start_in_own_process_group(builder: &mut Command) {
    use std::os::unix::process::CommandExt;

    builder.process_group(0);
}

#[cfg(not(unix))]
fn start_in_own_process_group(_builder: &mut Command) {}

#[cfg(unix)]
fn supervise_with_its_children(
    child: std::process::Child,
) -> io::Result<Box<dyn Child + Send + Sync>> {
    let group_leader = crate::process_group::ProcessGroupLeader::new(child)?;
    Ok(Box::new(group_leader))
}

#[cfg(not(unix))]
fn supervise_with_its_children(
    child: std::process::Child,
) -> io::Result<Box<dyn Child + Send + Sync>> {
    Ok(Box::new(child))
}

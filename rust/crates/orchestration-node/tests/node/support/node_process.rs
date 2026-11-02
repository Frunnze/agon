use std::io::{BufRead, BufReader, Write};
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::sync::{Mutex, MutexGuard, PoisonError};
use std::time::Duration;

use serde_json::Value;

use super::test_device::{describe, read_success};
use super::waiting::wait_for;

const HOST_PROGRAM: &str = env!("CARGO_BIN_EXE_orchestration_node_host");
const STOP_LIMIT: Duration = Duration::from_secs(30);

pub type EnvironmentVariable = (&'static str, String);

#[derive(Debug)]
pub struct ProcessSetup<'setup> {
    pub configuration: &'setup Value,
    pub environment: &'setup [EnvironmentVariable],
}

#[derive(Debug)]
struct ProcessPipes {
    commands: Option<ChildStdin>,
    replies: BufReader<ChildStdout>,
}

#[derive(Debug)]
pub struct NodeProcess {
    child: Child,
    pipes: Mutex<ProcessPipes>,
}

impl NodeProcess {
    pub fn start(setup: &ProcessSetup<'_>) -> Result<Self, String> {
        let mut host = Command::new(HOST_PROGRAM);
        host.stdin(Stdio::piped()).stdout(Stdio::piped());
        for (name, value) in setup.environment {
            host.env(name, value);
        }
        let mut child = host.spawn().map_err(describe)?;

        let commands = child.stdin.take().ok_or("the host has no input")?;
        let replies = child.stdout.take().ok_or("the host has no output")?;
        let pipes = ProcessPipes {
            commands: Some(commands),
            replies: BufReader::new(replies),
        };
        let process = Self {
            child,
            pipes: Mutex::new(pipes),
        };
        let started = process.send(setup.configuration)?;
        read_success(&started)?;
        Ok(process)
    }

    pub fn send(&self, message: &Value) -> Result<Value, String> {
        let mut pipes = self.lock_pipes();
        let commands =
            pipes.commands.as_mut().ok_or("the host input is closed")?;
        writeln!(commands, "{message}").map_err(describe)?;
        commands.flush().map_err(describe)?;

        let mut reply_line = String::new();
        let read_length =
            pipes.replies.read_line(&mut reply_line).map_err(describe)?;
        if read_length == 0 {
            return Err("the host process ended".to_owned());
        }
        serde_json::from_str(&reply_line).map_err(describe)
    }

    pub fn run(&self, command: &Value) -> Result<Value, String> {
        read_success(&self.send(command)?)
    }

    pub fn stop(mut self) -> Result<bool, String> {
        let closed_input = self.lock_pipes().commands.take();
        drop(closed_input);
        let exit = wait_for(STOP_LIMIT, "the host to stop", || {
            self.child.try_wait().map_err(describe)
        })?;
        Ok(exit.success())
    }

    fn lock_pipes(&self) -> MutexGuard<'_, ProcessPipes> {
        self.pipes.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

impl Drop for NodeProcess {
    fn drop(&mut self) {
        let is_running = matches!(self.child.try_wait(), Ok(None));
        if is_running {
            let _kill_outcome = self.child.kill();
            let _exit = self.child.wait();
        }
    }
}

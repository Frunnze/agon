use std::io::{BufRead, BufReader, Write};
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::sync::{Arc, Mutex, PoisonError};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use serde_json::Value;

use crate::support::test_device::{describe, read_success};
use crate::support::waiting::wait_for;

const HOST_PROGRAM: &str = env!("CARGO_BIN_EXE_orchestration_node_host");
const STOP_LIMIT: Duration = Duration::from_secs(30);
const LOG_READER_PANICKED: &str = "the log reader panicked";

type LoggedLines = Arc<Mutex<Vec<String>>>;

#[derive(Debug)]
pub struct LoggedHost {
    child: Child,
    commands: Option<ChildStdin>,
    replies: BufReader<ChildStdout>,
    logged_lines: LoggedLines,
    log_reader: Option<JoinHandle<()>>,
}

fn collect_lines(source: impl BufRead, logged_lines: &LoggedLines) {
    for line in source.lines().map_while(Result::ok) {
        let mut kept =
            logged_lines.lock().unwrap_or_else(PoisonError::into_inner);
        kept.push(line);
    }
}

impl LoggedHost {
    pub fn start(configuration: &Value) -> Result<Self, String> {
        let mut host = Command::new(HOST_PROGRAM);
        host.stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        let mut child = host.spawn().map_err(describe)?;
        let commands = child.stdin.take().ok_or("the host has no input")?;
        let replies = child.stdout.take().ok_or("the host has no output")?;
        let errors = child.stderr.take().ok_or("the host has no log")?;

        let logged_lines = LoggedLines::default();
        let reader_lines = Arc::clone(&logged_lines);
        let log_reader = thread::spawn(move || {
            collect_lines(BufReader::new(errors), &reader_lines);
        });
        let mut host = Self {
            child,
            commands: Some(commands),
            replies: BufReader::new(replies),
            logged_lines,
            log_reader: Some(log_reader),
        };
        let started = host.send(configuration)?;
        read_success(&started)?;
        Ok(host)
    }

    pub fn run(&mut self, command: &Value) -> Result<Value, String> {
        let reply = self.send(command)?;
        read_success(&reply)
    }

    pub fn read_logged_lines(&self) -> Vec<String> {
        let kept = self
            .logged_lines
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        kept.clone()
    }

    pub fn stop(mut self) -> Result<Vec<String>, String> {
        drop(self.commands.take());
        let exit = wait_for(STOP_LIMIT, "the host to stop", || {
            self.child.try_wait().map_err(describe)
        })?;
        if !exit.success() {
            return Err(format!("the host ended with {exit}"));
        }
        if let Some(log_reader) = self.log_reader.take() {
            log_reader
                .join()
                .map_err(|_| LOG_READER_PANICKED.to_owned())?;
        }
        Ok(self.read_logged_lines())
    }

    fn send(&mut self, message: &Value) -> Result<Value, String> {
        let commands =
            self.commands.as_mut().ok_or("the host input is closed")?;
        writeln!(commands, "{message}").map_err(describe)?;
        commands.flush().map_err(describe)?;
        let mut reply_line = String::new();
        let read_length =
            self.replies.read_line(&mut reply_line).map_err(describe)?;
        if read_length == 0 {
            return Err("the host process ended".to_owned());
        }
        serde_json::from_str(&reply_line).map_err(describe)
    }
}

impl Drop for LoggedHost {
    fn drop(&mut self) {
        let is_running = matches!(self.child.try_wait(), Ok(None));
        if is_running {
            let _kill_outcome = self.child.kill();
            let _exit = self.child.wait();
        }
    }
}

pub fn count_lines_starting(lines: &[String], line_start: &str) -> usize {
    let mut count = 0;
    for line in lines {
        if line.starts_with(line_start) {
            count += 1;
        }
    }
    count
}

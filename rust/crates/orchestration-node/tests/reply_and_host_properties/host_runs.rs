use std::io::{Read, Write};
use std::process::{Command, Stdio};
use std::time::Duration;

use serde_json::{Value, json};
use tempfile::TempDir;

use crate::support::test_device::{RELAY_DISABLED, describe};
use crate::support::waiting::wait_for;

const HOST_PROGRAM: &str = env!("CARGO_BIN_EXE_orchestration_node_host");
const FINISH_LIMIT: Duration = Duration::from_secs(60);
const FILE_IDENTITY_STORE: &str = "file";
const RUNNER_OFF: &str = "off";
const LINE_END: u8 = b'\n';
const LINE_END_CHARACTER: char = '\n';

#[derive(Debug)]
pub struct HostRun {
    pub exit_code: Option<i32>,
    pub reply_lines: Vec<String>,
}

pub fn quiet_configuration(data_directory: &TempDir) -> Value {
    json!({
        "data_directory": data_directory.path(),
        "identity_store": FILE_IDENTITY_STORE,
        "peer_relay": RELAY_DISABLED,
        "runner": RUNNER_OFF,
    })
}

pub fn join_input_lines(input_lines: &[Vec<u8>]) -> Vec<u8> {
    let mut input = Vec::new();
    for input_line in input_lines {
        input.extend_from_slice(input_line);
        input.push(LINE_END);
    }
    input
}

pub fn run_host(input: &[u8]) -> Result<HostRun, String> {
    let mut host = Command::new(HOST_PROGRAM)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(describe)?;
    let mut commands = host.stdin.take().ok_or("the host has no input")?;
    commands.write_all(input).map_err(describe)?;
    drop(commands);

    let finished = wait_for(FINISH_LIMIT, "the host to finish", || {
        host.try_wait().map_err(describe)
    });
    if finished.is_err() {
        let _kill_outcome = host.kill();
        let _exit = host.wait();
    }
    let exit = finished?;

    let mut replies = host.stdout.take().ok_or("the host has no output")?;
    let mut reply_text = String::new();
    replies.read_to_string(&mut reply_text).map_err(describe)?;
    let reply_lines = reply_text
        .split_terminator(LINE_END_CHARACTER)
        .map(str::to_owned)
        .collect();
    Ok(HostRun {
        exit_code: exit.code(),
        reply_lines,
    })
}

pub fn parse_reply_lines(host_run: &HostRun) -> Result<Vec<Value>, String> {
    let mut replies = Vec::new();
    for reply_line in &host_run.reply_lines {
        let reply = serde_json::from_str(reply_line).map_err(describe)?;
        replies.push(reply);
    }
    Ok(replies)
}

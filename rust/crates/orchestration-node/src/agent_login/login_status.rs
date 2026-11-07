use std::io::ErrorKind;
use std::process::{Command, Stdio};

use orchestration_hub::agent_command::CLAUDE_PROGRAM;
use serde::Serialize;
use serde_json::{Map, Value};

use crate::node_error::NodeError;

const STATUS_ARGUMENTS: [&str; 3] = ["auth", "status", "--json"];
const LOGGED_IN_FIELD: &str = "loggedIn";
const MISSING_LOGGED_IN_PROBLEM: &str =
    "the answer has no true or false loggedIn field";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ClaudeLogin {
    LoggedIn,
    NotLoggedIn,
    NotInstalled,
    Unknown,
}

pub fn read_claude_login() -> Result<ClaudeLogin, NodeError> {
    let answer = Command::new(CLAUDE_PROGRAM)
        .args(STATUS_ARGUMENTS)
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output();
    match answer {
        Ok(output) => {
            interpret_login_answer(&String::from_utf8_lossy(&output.stdout))
        }
        Err(problem) if problem.kind() == ErrorKind::NotFound => {
            Ok(ClaudeLogin::NotInstalled)
        }
        Err(problem) => {
            Err(NodeError::ClaudeStatusUnreadable(problem.to_string()))
        }
    }
}

pub fn interpret_login_answer(answer: &str) -> Result<ClaudeLogin, NodeError> {
    let fields: Map<String, Value> = serde_json::from_str(answer.trim())
        .map_err(|problem| {
            NodeError::ClaudeStatusUnreadable(problem.to_string())
        })?;
    let is_logged_in = fields
        .get(LOGGED_IN_FIELD)
        .and_then(Value::as_bool)
        .ok_or_else(|| {
            let problem = MISSING_LOGGED_IN_PROBLEM.to_owned();
            NodeError::ClaudeStatusUnreadable(problem)
        })?;
    if is_logged_in {
        return Ok(ClaudeLogin::LoggedIn);
    }
    Ok(ClaudeLogin::NotLoggedIn)
}

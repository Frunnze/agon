use std::io::ErrorKind;
use std::process::{Command, Stdio};

use orchestration_hub::agent_command::CLAUDE_PROGRAM;
use serde::{Deserialize, Serialize};

use crate::node_error::NodeError;

const STATUS_ARGUMENTS: [&str; 3] = ["auth", "status", "--json"];

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ClaudeLogin {
    LoggedIn,
    NotLoggedIn,
    NotInstalled,
}

#[derive(Deserialize)]
struct StatusAnswer {
    #[serde(rename = "loggedIn")]
    logged_in: bool,
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
    let parsed: StatusAnswer =
        serde_json::from_str(answer.trim()).map_err(|problem| {
            NodeError::ClaudeStatusUnreadable(problem.to_string())
        })?;
    if parsed.logged_in {
        return Ok(ClaudeLogin::LoggedIn);
    }
    Ok(ClaudeLogin::NotLoggedIn)
}

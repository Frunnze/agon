use std::fs;

use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde_json::{Value, json};

use crate::support::login_runner::{
    ClaudePresence, LoginRunner, local_sandbox,
};
use crate::support::test_device::fail;

pub const LOGIN_RUNNER_CASES: u32 = 3;
pub const STOPPED_PROBLEM: &str = "the login was stopped";
pub const CONTAINER_PLACE: &str = "container";
pub const LOCAL_PLACE: &str = "local_process";
pub const FAILED_STATE: &str = "failed";
pub const CLAUDE_LOGIN_FIELD: &str = "claude_login";
pub const CREDENTIAL_KIND_FIELD: &str = "container_credential";
pub const UNKNOWN_LOGIN: &str = "unknown";
pub const LOGGED_IN: &str = "logged_in";
pub const NOT_LOGGED_IN: &str = "not_logged_in";
pub const TYPED_CODE_FILE_NAME: &str = "login-code";
const CRASH_SIGNAL_FILE_NAME: &str = "crash-signal";
const STATUS_ANSWER_FILE_NAME: &str = "status-answer";
const CRASH_SIGNALS: [&str; 8] =
    ["KILL", "SEGV", "ABRT", "TERM", "HUP", "BUS", "QUIT", "USR1"];

pub fn any_place() -> impl Strategy<Value = &'static str> {
    prop_oneof![Just(CONTAINER_PLACE), Just(LOCAL_PLACE)]
}

pub fn any_crash_signal() -> impl Strategy<Value = &'static str> {
    proptest::sample::select(CRASH_SIGNALS.to_vec())
}

pub fn any_login_code() -> impl Strategy<Value = String> {
    "[A-Za-z0-9_-]{1,40}"
}

pub fn start_nodes() -> Result<LoginRunner, TestCaseError> {
    LoginRunner::start(&local_sandbox(), ClaudePresence::Installed)
        .map_err(fail)
}

pub fn ask_for_a_crash(
    nodes: &LoginRunner,
    signal: &str,
) -> Result<(), TestCaseError> {
    let crash_path = nodes.records.path().join(CRASH_SIGNAL_FILE_NAME);
    fs::write(crash_path, signal).map_err(fail)
}

pub fn answer_status_with(
    nodes: &LoginRunner,
    answer: &str,
) -> Result<(), TestCaseError> {
    let answer_path = nodes.records.path().join(STATUS_ANSWER_FILE_NAME);
    fs::write(answer_path, answer).map_err(fail)
}

pub fn read_status(nodes: &LoginRunner) -> Result<Value, TestCaseError> {
    nodes.read_login_status().map_err(fail)
}

pub fn save_api_key(
    nodes: &LoginRunner,
    api_key: &str,
) -> Result<(), TestCaseError> {
    let command =
        json!({ "command": "save_agent_api_key", "api_key": api_key });
    nodes.run(&command).map_err(fail)?;
    Ok(())
}

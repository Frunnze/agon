use std::fs;

use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde_json::{Value, json};

use crate::support::login_runner::{
    ClaudePresence, LoginRunner, local_sandbox,
};
use crate::support::test_device::{describe, fail};

pub const CONTAINER_PLACE: &str = "container";
pub const LOCAL_PLACE: &str = "local_process";
pub const LOGIN_PROMPT: &str = "Paste code here if prompted";
pub const ENTER_KEY: &str = "\r";
pub const TOKEN_START: &str = "sk-ant-oat01-";
pub const RUNNING_STATE: &str = "running";
pub const FINISHED_STATE: &str = "finished";
pub const FAILED_STATE: &str = "failed";
pub const CREDENTIAL_FILE_NAME: &str = "agent-credential.key";
pub const CREDENTIAL_KIND_FIELD: &str = "container_credential";
pub const CLAUDE_LOGIN_FIELD: &str = "claude_login";
pub const API_KEY_NAME: &str = "api_key";
pub const LOGGED_IN_RECORD_NAME: &str = "logged-in";
pub const TYPED_CODE_FILE_NAME: &str = "login-code";
pub const LOGIN_CASES: u32 = 2;

pub fn any_place() -> impl Strategy<Value = &'static str> {
    prop_oneof![Just(CONTAINER_PLACE), Just(LOCAL_PLACE)]
}

pub fn any_login_code() -> impl Strategy<Value = String> {
    "[A-Za-z0-9_-]{1,40}"
}

pub fn start_nodes() -> Result<LoginRunner, TestCaseError> {
    LoginRunner::start(&local_sandbox(), ClaudePresence::Installed)
        .map_err(fail)
}

pub fn start_nodes_without_claude() -> Result<LoginRunner, TestCaseError> {
    LoginRunner::start(&local_sandbox(), ClaudePresence::Missing).map_err(fail)
}

pub fn start_login(nodes: &LoginRunner, place: &str) -> Result<Value, String> {
    nodes.run(&json!({ "command": "start_agent_login", "place": place }))
}

pub fn read_login(nodes: &LoginRunner) -> Result<Value, String> {
    nodes.run(&json!({ "command": "read_agent_login" }))
}

pub fn type_keys(nodes: &LoginRunner, keys: &str) -> Result<Value, String> {
    nodes.run(&json!({ "command": "type_agent_login", "keys": keys }))
}

pub fn stop_login(nodes: &LoginRunner) -> Result<Value, String> {
    nodes.run(&json!({ "command": "stop_agent_login" }))
}

pub fn save_api_key(
    nodes: &LoginRunner,
    api_key: &str,
) -> Result<Value, String> {
    nodes.run(&json!({ "command": "save_agent_api_key", "api_key": api_key }))
}

pub fn read_status_field(
    nodes: &LoginRunner,
    field: &str,
) -> Result<Value, TestCaseError> {
    let status = nodes.read_login_status().map_err(fail)?;
    Ok(status[field].clone())
}

pub fn start_login_to_prompt(
    nodes: &LoginRunner,
    place: &str,
) -> Result<(), TestCaseError> {
    start_login(nodes, place).map_err(fail)?;
    nodes.wait_for_login_text(LOGIN_PROMPT).map_err(fail)
}

pub fn finish_login(
    nodes: &LoginRunner,
    place: &str,
    code: &str,
) -> Result<Value, TestCaseError> {
    start_login_to_prompt(nodes, place)?;
    type_keys(nodes, &format!("{code}{ENTER_KEY}")).map_err(fail)?;
    nodes.wait_for_login_end().map_err(fail)
}

pub fn fail_container_login(
    nodes: &LoginRunner,
) -> Result<Value, TestCaseError> {
    let ending = finish_login(nodes, CONTAINER_PLACE, "")?;
    if ending["state"] != FAILED_STATE {
        return Err(TestCaseError::fail(format!("not a failure: {ending}")));
    }
    Ok(ending)
}

pub fn read_kept_secret(nodes: &LoginRunner) -> Result<String, String> {
    let credential_path = nodes.data.path().join(CREDENTIAL_FILE_NAME);
    let kept_text = fs::read_to_string(credential_path).map_err(describe)?;
    let kept: Value = serde_json::from_str(&kept_text).map_err(describe)?;
    let secret = kept["secret"].as_str().ok_or("the secret is missing")?;
    Ok(secret.to_owned())
}

pub fn expected_command(place: &str) -> &'static str {
    if place == CONTAINER_PLACE {
        return "claude setup-token";
    }
    "claude auth login"
}

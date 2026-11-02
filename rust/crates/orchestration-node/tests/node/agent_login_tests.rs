use std::fs;

use serde_json::{Value, json};

use crate::support::login_runner::{
    ClaudePresence, LoginRunner, container_sandbox, find_text_in_folder,
    local_sandbox,
};
use crate::support::test_device::TestDevice;

const SETUP_CODE: &str = "RealStack_Token-42xYz";
const LONG_LIVED_TOKEN: &str = "sk-ant-oat01-RealStack_Token-42xYz";
const TOKEN_VARIABLE: &str = "CLAUDE_CODE_OAUTH_TOKEN";
const CREDENTIAL_FILE_NAME: &str = "agent-credential.key";
const WORKTREES_FOLDER_NAME: &str = "worktrees";
const RUNNER_UNAVAILABLE: &str = "this device cannot run tasks";

fn start_or_panic(sandbox: &Value, presence: ClaudePresence) -> LoginRunner {
    match LoginRunner::start(sandbox, presence) {
        Ok(started) => started,
        Err(problem) => panic!("the runner starts: {problem}"),
    }
}

fn token_assignment() -> String {
    format!("{TOKEN_VARIABLE}={LONG_LIVED_TOKEN}")
}

fn recorded_bodies_contain(nodes: &LoginRunner, needle: &str) -> bool {
    nodes
        .server
        .recorded_requests()
        .iter()
        .any(|request| String::from_utf8_lossy(&request.body).contains(needle))
}

#[test]
fn a_connected_token_reaches_the_container_and_nothing_else() {
    let mut nodes =
        start_or_panic(&container_sandbox(), ClaudePresence::Installed);
    let before = nodes.read_login_status();
    assert_eq!(
        before,
        Ok(json!({
            "claude_login": "not_logged_in",
            "container_credential": null,
        }))
    );

    let ending = nodes.log_in_through_the_terminal("container", SETUP_CODE);
    let Ok(ending) = ending else {
        panic!("the login ends: {ending:?}");
    };
    assert_eq!(ending["state"], "finished", "{ending}");
    assert_eq!(ending["command"], "claude setup-token");
    let shown_lines = ending["lines"].to_string();
    assert!(!shown_lines.contains(LONG_LIVED_TOKEN), "{shown_lines}");
    assert!(shown_lines.contains("Your OAuth token"), "{shown_lines}");
    let connected = nodes.read_login_status();
    assert_eq!(
        connected.map(|status| status["container_credential"].clone()),
        Ok(json!("long_lived_token"))
    );

    assert_eq!(nodes.run_a_task_to_done("Use the token"), Ok(()));
    let runs = nodes.read_container_runs();
    let Ok(runs) = runs else {
        panic!("the fake container recorded its runs: {runs:?}");
    };
    assert_eq!(runs.len(), 1, "{runs:?}");
    assert!(runs[0].contains(&token_assignment()), "{runs:?}");

    let stored_state = nodes.server.read_stored_state();
    assert!(stored_state.is_ok_and(|state| !state.contains(LONG_LIVED_TOKEN)));
    assert!(!recorded_bodies_contain(&nodes, LONG_LIVED_TOKEN));
    let worktrees = nodes.data.path().join(WORKTREES_FOLDER_NAME);
    assert_eq!(find_text_in_folder(&worktrees, LONG_LIVED_TOKEN), Ok(false));
    let kept =
        fs::read_to_string(nodes.data.path().join(CREDENTIAL_FILE_NAME));
    assert!(kept.is_ok_and(|text| text.contains(LONG_LIVED_TOKEN)));

    let forgotten =
        nodes.run(&json!({ "command": "forget_agent_credential" }));
    assert_eq!(forgotten, Ok(Value::Null));
    assert_eq!(nodes.run_a_task_to_done("Run without the token"), Ok(()));
    let runs = nodes.read_container_runs();
    let Ok(runs) = runs else {
        panic!("the fake container recorded its runs: {runs:?}");
    };
    assert_eq!(runs.len(), 2, "{runs:?}");
    assert!(!runs[1].contains(TOKEN_VARIABLE), "{runs:?}");
}

#[test]
fn logging_in_on_this_computer_runs_claude_auth_login() {
    let nodes = start_or_panic(&local_sandbox(), ClaudePresence::Installed);

    let ending = nodes.log_in_through_the_terminal("local_process", "abc");
    let status = nodes.read_login_status();

    let Ok(ending) = ending else {
        panic!("the login ends: {ending:?}");
    };
    assert_eq!(ending["state"], "finished", "{ending}");
    assert_eq!(ending["command"], "claude auth login");
    assert_eq!(
        status,
        Ok(json!({
            "claude_login": "logged_in",
            "container_credential": null,
        }))
    );
    let typed = fs::read_to_string(nodes.records.path().join("login-code"));
    let typed = typed.ok().map(|code| code.trim().to_owned());
    assert_eq!(typed.as_deref(), Some("abc"));
}

#[test]
fn a_computer_without_claude_says_it_is_not_installed() {
    let nodes = start_or_panic(&local_sandbox(), ClaudePresence::Missing);

    let status = nodes.read_login_status();
    let started = nodes.run(&json!({
        "command": "start_agent_login",
        "place": "local_process",
    }));

    assert_eq!(
        status.map(|status| status["claude_login"].clone()),
        Ok(json!("not_installed"))
    );
    assert!(started.is_err(), "{started:?}");
}

#[test]
fn an_api_key_is_kept_until_it_is_forgotten() {
    let nodes =
        start_or_panic(&container_sandbox(), ClaudePresence::Installed);

    let refused = nodes.run(&json!({
        "command": "save_agent_api_key",
        "api_key": "sk-ant has spaces",
    }));
    let saved = nodes.run(&json!({
        "command": "save_agent_api_key",
        "api_key": " sk-ant-api03-key \n",
    }));
    let with_key = nodes.read_login_status();
    let forgotten =
        nodes.run(&json!({ "command": "forget_agent_credential" }));
    let without_key = nodes.read_login_status();

    assert!(refused.is_err(), "{refused:?}");
    assert_eq!(saved, Ok(Value::Null));
    assert_eq!(
        with_key.map(|status| status["container_credential"].clone()),
        Ok(json!("api_key"))
    );
    assert_eq!(forgotten, Ok(Value::Null));
    assert_eq!(
        without_key.map(|status| status["container_credential"].clone()),
        Ok(Value::Null)
    );
}

#[test]
fn only_one_login_is_open_at_a_time() {
    let nodes =
        start_or_panic(&container_sandbox(), ClaudePresence::Installed);
    let start =
        json!({ "command": "start_agent_login", "place": "container" });

    let first = nodes.run(&start);
    let second = nodes.run(&start);
    let stopped = nodes.run(&json!({ "command": "stop_agent_login" }));
    let after_stop = nodes.run(&json!({ "command": "read_agent_login" }));
    let again = nodes.run(&start);

    assert_eq!(first, Ok(Value::Null));
    assert!(second.is_err(), "{second:?}");
    assert_eq!(stopped, Ok(Value::Null));
    assert_eq!(after_stop, Ok(Value::Null));
    assert_eq!(again, Ok(Value::Null));
}

#[test]
fn a_device_that_runs_no_tasks_refuses_the_login_commands() {
    let Ok(device) = TestDevice::start() else {
        panic!("the test device starts");
    };
    let commands = [
        json!({ "command": "agent_login_status" }),
        json!({ "command": "start_agent_login", "place": "container" }),
        json!({ "command": "read_agent_login" }),
        json!({ "command": "type_agent_login", "keys": "x" }),
        json!({ "command": "stop_agent_login" }),
        json!({ "command": "save_agent_api_key", "api_key": "sk-ant-x" }),
        json!({ "command": "forget_agent_credential" }),
    ];

    for command in commands {
        let refused = device.run(&command);

        assert_eq!(refused, Err(RUNNER_UNAVAILABLE.to_owned()), "{command}");
    }
}

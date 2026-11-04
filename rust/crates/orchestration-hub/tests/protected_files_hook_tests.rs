use std::error::Error;
use std::io::Write;
use std::process::{Command, Stdio};

use orchestration_core::protected_files::ProtectedFiles;
use orchestration_hub::protected_files_hook::write_protected_files_hook;
use proptest::prelude::*;
use serde_json::{Value, json};

const SHELL_PROGRAM: &str = "sh";
const SAMPLE_HOME: &str = "/Users/sample.person";
const DENY_DECISION: &str = "deny";
const HOOK_EVENT: &str = "PreToolUse";
const HOOK_CASES: u32 = 24;

type TestResult = Result<(), TestCaseError>;
type Decision = Result<bool, TestCaseError>;

fn run_hook(
    hook: &str,
    tool_name: &str,
    tool_input: &Value,
) -> Result<String, Box<dyn Error>> {
    let hook_input = json!({
        "session_id": "a1b2",
        "transcript_path": "/tmp/transcript.jsonl",
        "cwd": "/workspace",
        "hook_event_name": HOOK_EVENT,
        "tool_name": tool_name,
        "tool_input": tool_input,
    });
    let mut child = Command::new(SHELL_PROGRAM)
        .arg("-c")
        .arg(hook)
        .env("HOME", SAMPLE_HOME)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()?;
    let mut input = child.stdin.take().ok_or("the hook reads no input")?;
    input.write_all(hook_input.to_string().as_bytes())?;
    drop(input);
    let output = child.wait_with_output()?;
    if !output.status.success() {
        return Err(format!("the hook failed: {output:?}").into());
    }
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

fn is_denied(hook_output: &str) -> Result<bool, Box<dyn Error>> {
    if hook_output.trim().is_empty() {
        return Ok(false);
    }
    let decision: Value = serde_json::from_str(hook_output)?;
    let specific = &decision["hookSpecificOutput"];
    let reason = specific["permissionDecisionReason"].as_str();
    let has_reason = reason.is_some_and(|reason| !reason.is_empty());
    let is_hook_event = specific["hookEventName"] == HOOK_EVENT;
    if !has_reason || !is_hook_event {
        return Err(format!("not a refusal: {hook_output}").into());
    }
    Ok(specific["permissionDecision"] == DENY_DECISION)
}

fn decide_tool(hook: &str, tool_name: &str, tool_input: &Value) -> Decision {
    let decision = run_hook(hook, tool_name, tool_input)
        .and_then(|hook_output| is_denied(&hook_output));
    decision.map_err(|problem| TestCaseError::fail(problem.to_string()))
}

fn decide_read(hook: &str, file_path: &str) -> Decision {
    decide_tool(hook, "Read", &json!({ "file_path": file_path }))
}

fn decide_command(hook: &str, command: &str) -> Decision {
    let tool_input = json!({ "command": command, "description": "Look" });
    decide_tool(hook, "Bash", &tool_input)
}

fn default_hook() -> String {
    write_protected_files_hook(&ProtectedFiles::default())
}

fn hook_for(patterns: &[&str]) -> String {
    let protected = ProtectedFiles {
        patterns: patterns.iter().map(ToString::to_string).collect(),
    };
    write_protected_files_hook(&protected)
}

#[test]
fn test_write_protected_files_hook_property_refuses_env_files_by_any_tool()
-> TestResult {
    let hook = default_hook();
    let grep_input = json!({ "pattern": "KEY", "path": "app/.env" });

    assert!(decide_read(&hook, "/workspace/app/.env")?);
    assert!(decide_read(&hook, "/workspace/.env.local")?);
    assert!(decide_command(&hook, "cat .env")?);
    assert!(decide_command(&hook, "cat \"config/.env.production\"")?);
    assert!(decide_command(&hook, "grep KEY app/.env | head")?);
    assert!(decide_tool(&hook, "Grep", &grep_input)?);
    Ok(())
}

#[test]
fn test_write_protected_files_hook_property_allows_lookalikes() -> TestResult {
    let hook = default_hook();

    assert!(!decide_read(&hook, "/workspace/app/.envrc")?);
    assert!(!decide_command(&hook, "ls .venv/bin")?);
    assert!(!decide_command(&hook, "cat production.env")?);
    assert!(!decide_read(&hook, "/workspace/README.md")?);
    Ok(())
}

#[test]
fn test_write_protected_files_hook_property_follows_patterns_as_written()
-> TestResult {
    let only_env_file = hook_for(&[".env"]);

    assert!(decide_read(&only_env_file, "/workspace/.env")?);
    assert!(!decide_read(&only_env_file, "/workspace/.env.example")?);
    assert!(!decide_command(&only_env_file, "cat .env.example")?);
    Ok(())
}

#[test]
fn test_write_protected_files_hook_property_refuses_home_files() -> TestResult
{
    let hook = default_hook();
    let home_config = format!("{SAMPLE_HOME}/.ssh/config");
    let browser_listing =
        "ls \"$HOME/Library/Application Support/Google/Chrome\"";

    assert!(decide_command(&hook, "cat ~/.ssh/id_ed25519")?);
    assert!(decide_command(&hook, "cat $HOME/.aws/credentials")?);
    assert!(decide_command(&hook, "cat ${HOME}/.npmrc")?);
    assert!(decide_read(&hook, &home_config)?);
    assert!(decide_command(&hook, browser_listing)?);
    Ok(())
}

#[test]
fn test_write_protected_files_hook_property_home_is_only_home() -> TestResult {
    let hook = default_hook();

    assert!(!decide_read(&hook, "/workspace/project/.ssh/config")?);
    assert!(!decide_command(&hook, "cat ~/.sshrc")?);
    assert!(!decide_command(&hook, "ls ~/projects")?);
    Ok(())
}

#[test]
fn test_write_protected_files_hook_property_ignores_written_content()
-> TestResult {
    let hook = default_hook();
    let tool_input = json!({
        "file_path": "/workspace/.gitignore",
        "content": ".env\n.env.*\n~/.ssh\n",
    });

    assert!(!decide_tool(&hook, "Write", &tool_input)?);
    Ok(())
}

#[test]
fn test_write_protected_files_hook_property_globs_match_names() -> TestResult {
    let hook = hook_for(&["*.pem", "~/.config/**/token.json"]);

    assert!(decide_command(&hook, "openssl x509 -in certs/server.pem")?);
    assert!(decide_read(&hook, "/workspace/server.PEM")?);
    assert!(!decide_read(&hook, "/workspace/server.pem.txt")?);
    assert!(decide_command(&hook, "cat ~/.config/tool/v2/token.json")?);
    assert!(decide_command(&hook, "cat ~/.config/token.json")?);
    assert!(!decide_command(&hook, "cat ~/.config/tool/settings.json")?);
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOOK_CASES))]

    #[test]
    fn test_write_protected_files_hook_property_env_file_at_any_depth(
        folders in proptest::collection::vec("[a-z][a-z0-9_-]{0,6}", 0..4),
    ) {
        let hook = default_hook();
        let folder_path = folders.join("/");
        let file_path = format!("/workspace/{folder_path}/.env");
        let command = format!("cat {file_path}");

        let is_read_denied =
            decide_read(&hook, &file_path)?;
        let is_command_denied =
            decide_command(&hook, &command)?;

        prop_assert!(is_read_denied);
        prop_assert!(is_command_denied);
    }

    #[test]
    fn test_write_protected_files_hook_property_plain_files_are_allowed(
        folders in proptest::collection::vec("[a-z][a-z0-9_-]{0,6}", 0..4),
        name in "[a-z][a-z0-9_-]{0,8}\\.(md|rs|txt|json)",
    ) {
        let hook = default_hook();
        let folder_path = folders.join("/");
        let file_path = format!("/workspace/{folder_path}/{name}");
        let command = format!("cat {file_path}");

        let is_read_denied =
            decide_read(&hook, &file_path)?;
        let is_command_denied =
            decide_command(&hook, &command)?;

        prop_assert!(!is_read_denied);
        prop_assert!(!is_command_denied);
    }
}

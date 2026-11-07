use std::fmt::Display;
use std::io::Write;
use std::process::{Command, Stdio};

use orchestration_core::protected_files::{
    ProtectedFiles, validate_protected_pattern,
};
use orchestration_hub::protected_files_hook::{
    REFUSAL_REASON, write_protected_files_hook,
};
use proptest::prelude::*;
use serde_json::{Value, json};

pub type Decision = Result<bool, TestCaseError>;

pub const HOOK_CASES: u32 = 32;

const SHELL_PROGRAM: &str = "sh";
const HOME_VARIABLE: &str = "HOME";
const HOOK_EVENT: &str = "PreToolUse";
const DENY_DECISION: &str = "deny";

pub fn to_case_error(problem: impl Display) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

pub fn protect(patterns: &[String]) -> ProtectedFiles {
    ProtectedFiles {
        patterns: patterns.to_vec(),
    }
}

pub fn hook_for(patterns: &[String]) -> String {
    write_protected_files_hook(&protect(patterns))
}

pub fn run_hook(
    hook: &str,
    home: &str,
    tool_name: &str,
    tool_input: &Value,
) -> Result<String, TestCaseError> {
    let hook_input = json!({
        "hook_event_name": HOOK_EVENT,
        "tool_name": tool_name,
        "tool_input": tool_input,
    });
    let mut child = Command::new(SHELL_PROGRAM)
        .arg("-c")
        .arg(hook)
        .env(HOME_VARIABLE, home)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .map_err(to_case_error)?;
    let mut input = child
        .stdin
        .take()
        .ok_or_else(|| to_case_error("the hook takes no input"))?;
    input
        .write_all(hook_input.to_string().as_bytes())
        .map_err(to_case_error)?;
    drop(input);

    let output = child.wait_with_output().map_err(to_case_error)?;
    if !output.status.success() {
        return Err(to_case_error(format!("the hook failed: {output:?}")));
    }
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

pub fn read_refusal(hook_output: &str) -> Decision {
    if hook_output.is_empty() {
        return Ok(false);
    }
    let decision: Value =
        serde_json::from_str(hook_output).map_err(to_case_error)?;
    let specific = &decision["hookSpecificOutput"];
    let is_refusal = specific["hookEventName"] == HOOK_EVENT
        && specific["permissionDecision"] == DENY_DECISION
        && specific["permissionDecisionReason"] == REFUSAL_REASON;
    if !is_refusal {
        return Err(to_case_error(format!("not a refusal: {hook_output}")));
    }
    Ok(true)
}

pub fn decide_tool(
    hook: &str,
    home: &str,
    tool_name: &str,
    tool_input: &Value,
) -> Decision {
    let hook_output = run_hook(hook, home, tool_name, tool_input)?;
    read_refusal(&hook_output)
}

pub fn decide_read(hook: &str, home: &str, file_path: &str) -> Decision {
    decide_tool(hook, home, "Read", &json!({ "file_path": file_path }))
}

pub fn decide_command(hook: &str, home: &str, command: &str) -> Decision {
    decide_tool(hook, home, "Bash", &json!({ "command": command }))
}

pub fn any_name() -> impl Strategy<Value = String> {
    "[a-z][a-z0-9_-]{0,7}"
}

pub fn any_home() -> impl Strategy<Value = String> {
    proptest::collection::vec("[A-Za-z][A-Za-z0-9._-]{0,7}", 1..4)
        .prop_map(|folders| format!("/{}", folders.join("/")))
}

pub fn any_valid_pattern() -> impl Strategy<Value = String> {
    let name = "[A-Za-z0-9._ -]{0,3}[*?]?[A-Za-z0-9._-]{1,4}";
    let segments = proptest::collection::vec(
        prop_oneof![4 => name.boxed(), 1 => Just("**".to_owned()).boxed()],
        1..4,
    );
    let place = prop_oneof![Just("~/"), Just("/"), Just("")];
    (place, segments)
        .prop_map(|(place, segments)| format!("{place}{}", segments.join("/")))
        .prop_filter("the core accepts the pattern", |pattern| {
            validate_protected_pattern(pattern).is_ok()
        })
}

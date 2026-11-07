use serde_json::{Value, json};

use crate::hosting_desk::start_node_with;
use crate::support::test_device::{describe, read_success};

const HOSTING_PROBLEM_FIELD: &str = "hosting_problem";
const NO_HOSTING_PROBLEM: &str = "the started node names no hosting problem";

pub fn read_hosting_problem_after_start(
    configuration: &Value,
) -> Result<String, String> {
    let runtime = start_node_with(configuration)?;
    let status_command = json!({ "command": "status" });
    let reply_text = runtime.handle_command(&status_command.to_string());
    let reply: Value = serde_json::from_str(&reply_text).map_err(describe)?;
    let status = read_success(&reply)?;
    let problem = status[HOSTING_PROBLEM_FIELD].as_str();
    problem
        .map(str::to_owned)
        .ok_or_else(|| NO_HOSTING_PROBLEM.to_owned())
}

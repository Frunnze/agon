use serde_json::{Value, json};

use crate::command_builders::{PreparedWorkspace, prepare_workspace};
use crate::test_device::read_text;

pub const TITLE_CASES: u32 = 4;
const MARKDOWN_POINTER: &str = "/markdown";
const RULE_LINE_PREFIX: &str = "- ";

pub fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

pub fn everywhere_scope() -> Value {
    json!({
        "workspaces": { "kind": "all_workspaces" },
        "projects": { "kind": "all_projects" },
    })
}

pub fn create_rule(
    prepared: &PreparedWorkspace,
    title: &str,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "create_rule",
        "workspace_id": prepared.workspace_id,
        "title": title,
        "details": "",
        "scope": everywhere_scope(),
    }))
}

pub fn update_rule(
    prepared: &PreparedWorkspace,
    rule_id: &Value,
    title: &str,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "update_rule",
        "workspace_id": prepared.workspace_id,
        "rule_id": rule_id,
        "title": title,
        "details": "",
        "scope": everywhere_scope(),
    }))
}

pub fn list_rule_titles(
    prepared: &PreparedWorkspace,
) -> Result<Vec<Value>, String> {
    let rules = prepared.device.run(&json!({
        "command": "list_rules",
        "workspace_id": prepared.workspace_id,
    }))?;
    let listed_rules = rules.as_array().cloned().unwrap_or_default();
    let mut titles = Vec::new();
    for rule in listed_rules {
        titles.push(rule["title"].clone());
    }
    Ok(titles)
}

pub fn list_agents_markdown_rule_lines(
    prepared: &PreparedWorkspace,
) -> Result<Vec<String>, String> {
    let view = prepared.device.run(&json!({
        "command": "show_agents_markdown",
        "workspace_id": prepared.workspace_id,
        "project_id": prepared.project_id,
    }))?;
    let markdown = read_text(&view, MARKDOWN_POINTER)?;
    let mut rule_lines = Vec::new();
    for line in markdown.lines() {
        if line.starts_with(RULE_LINE_PREFIX) {
            rule_lines.push(line.to_owned());
        }
    }
    Ok(rule_lines)
}

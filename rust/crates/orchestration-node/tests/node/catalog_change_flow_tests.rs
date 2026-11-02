use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_rule_command, create_workflow_command,
    prepare_workspace,
};
use crate::support::test_device::{fail, read_text};

const CATALOG_CASES: u32 = 4;
const MOST_TOGGLES: usize = 5;
const SIGNED_TASK: &str = "Plan the release";
const NAME_PATTERN: &str = "[a-z][a-z0-9]{0,10}";
const CHANGED_TASK_PATTERN: &str = "[A-Z][a-z ]{0,30}";
const RULE_DETAILS_PATTERN: &str = "[a-z]{8,16}";
const REENABLED_RULE_DETAILS: &str = "rule details that come back";

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn find_by_id(listed: &Value, pointer: &str, id: &Value) -> Option<Value> {
    let entries = listed.as_array()?;
    let found = entries
        .iter()
        .find(|entry| entry.pointer(pointer) == Some(id));
    found.cloned()
}

fn create_signed_workflow(
    prepared: &PreparedWorkspace,
) -> Result<Value, String> {
    let command = create_workflow_command(&prepared.workspace_id, SIGNED_TASK);
    let created = prepared.device.run(&command)?;
    prepared.device.run(&json!({
        "command": "sign_workflow",
        "workflow_id": created["workflow"]["id"],
    }))
}

fn set_rule_enabled(
    prepared: &PreparedWorkspace,
    rule_id: &Value,
    enabled: bool,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "set_rule_enabled",
        "rule_id": rule_id,
        "enabled": enabled,
    }))
}

fn read_rule_state(
    prepared: &PreparedWorkspace,
    rule_id: &Value,
) -> Result<(Value, String), String> {
    let rules = prepared.device.run(&json!({
        "command": "list_rules",
        "workspace_id": prepared.workspace_id,
    }))?;
    let rule = find_by_id(&rules, "/id", rule_id)
        .ok_or_else(|| "the rule is not listed".to_owned())?;
    let markdown = prepared.device.run(&json!({
        "command": "show_agents_markdown",
        "workspace_id": prepared.workspace_id,
        "project_id": prepared.project_id,
    }))?;
    Ok((rule["enabled"].clone(), read_text(&markdown, "/markdown")?))
}

#[test]
fn test_create_repository_property_the_project_lists_the_new_repository() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(CATALOG_CASES));

    let outcome = runner.run(&(NAME_PATTERN, NAME_PATTERN), |names| {
        let (owner, repository) = names;
        let address = format!("https://github.com/{owner}/r-{repository}.git");
        let canonical = format!("github.com/{owner}/r-{repository}");

        let created = device
            .run(&json!({
                "command": "create_repository",
                "project_id": prepared.project_id,
                "repository": {
                    "address": address,
                    "default_branch": "main",
                    "agent_access": "read_only",
                },
            }))
            .map_err(fail)?;
        let repositories = device
            .run(&json!({
                "command": "list_repositories",
                "project_id": prepared.project_id,
            }))
            .map_err(fail)?;
        let projects = device
            .run(&json!({
                "command": "list_projects",
                "workspace_id": prepared.workspace_id,
            }))
            .map_err(fail)?;

        prop_assert_eq!(&created["address"], &Value::String(canonical));
        let listed =
            find_by_id(&repositories, "/address", &created["address"]);
        prop_assert_eq!(listed.as_ref(), Some(&created));
        let project_id = json!(prepared.project_id);
        let project = find_by_id(&projects, "/project/id", &project_id)
            .ok_or_else(|| fail("the project is not listed"))?;
        let in_project = find_by_id(
            &project["project"]["repositories"],
            "/address",
            &created["address"],
        );
        prop_assert_eq!(in_project.as_ref(), Some(&created));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_discard_workflow_change_property_restores_the_signed_version() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(CATALOG_CASES));

    let outcome = runner.run(&CHANGED_TASK_PATTERN, |changed_task| {
        prop_assume!(changed_task != SIGNED_TASK);
        let signed = create_signed_workflow(&prepared).map_err(fail)?;
        let mut changed_workflow = signed["workflow"].clone();
        changed_workflow["agents"][0]["task"] = json!(changed_task);
        let changed = device
            .run(&json!({
                "command": "save_workflow",
                "workspace_id": prepared.workspace_id,
                "workflow": changed_workflow,
            }))
            .map_err(fail)?;

        let discarded = device
            .run(&json!({
                "command": "discard_workflow_change",
                "workflow_id": signed["workflow"]["id"],
            }))
            .map_err(fail)?;
        let workflows = device
            .run(&json!({
                "command": "list_workflows",
                "workspace_id": prepared.workspace_id,
            }))
            .map_err(fail)?;

        prop_assert_eq!(&changed["signature_state"], "changed_not_signed");
        prop_assert_eq!(&discarded["signature_state"], "signed");
        prop_assert_eq!(&discarded["workflow"], &signed["workflow"]);
        prop_assert_eq!(&discarded["changes"], &json!([]));
        let listed =
            find_by_id(&workflows, "/workflow/id", &signed["workflow"]["id"])
                .ok_or_else(|| fail("the workflow is not listed"))?;
        prop_assert_eq!(&listed["workflow"]["agents"][0]["task"], SIGNED_TASK);
        prop_assert_eq!(&listed["signature_state"], "signed");
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_set_rule_enabled_property_the_last_choice_wins() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(CATALOG_CASES));
    let choices = (RULE_DETAILS_PATTERN, vec(any::<bool>(), 1..MOST_TOGGLES));

    let outcome = runner.run(&choices, |(details, toggles)| {
        let command = create_rule_command(&prepared.workspace_id, &details);
        let rule = device.run(&command).map_err(fail)?;
        for enabled in &toggles {
            let toggled = set_rule_enabled(&prepared, &rule["id"], *enabled);
            prop_assert_eq!(toggled, Ok(Value::Null));
        }

        let (enabled, markdown) =
            read_rule_state(&prepared, &rule["id"]).map_err(fail)?;

        let last_choice = toggles.last().copied().unwrap_or_default();
        prop_assert_eq!(enabled, json!(last_choice));
        prop_assert_eq!(markdown.contains(&details), last_choice);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn set_rule_enabled_brings_a_disabled_rule_back() {
    let prepared = prepared_or_panic();
    let command =
        create_rule_command(&prepared.workspace_id, REENABLED_RULE_DETAILS);
    let Ok(rule) = prepared.device.run(&command) else {
        panic!("the rule is created");
    };
    let disabled = set_rule_enabled(&prepared, &rule["id"], false);
    let while_disabled = read_rule_state(&prepared, &rule["id"]);

    let enabled = set_rule_enabled(&prepared, &rule["id"], true);
    let after_enabling = read_rule_state(&prepared, &rule["id"]);

    assert_eq!(disabled, Ok(Value::Null));
    assert_eq!(enabled, Ok(Value::Null));
    let (Ok(while_disabled), Ok(after_enabling)) =
        (while_disabled, after_enabling)
    else {
        panic!("the rule state is readable");
    };
    assert_eq!(while_disabled.0, json!(false));
    assert!(!while_disabled.1.contains(REENABLED_RULE_DETAILS));
    assert_eq!(after_enabling.0, json!(true));
    assert!(after_enabling.1.contains(REENABLED_RULE_DETAILS));
}

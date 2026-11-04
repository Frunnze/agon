use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_project_command, create_task_command,
    prepare_workspace,
};
use crate::support::test_device::{TestDevice, fail, read_text};

const SETTING_CASES: u32 = 4;
const AUTO_WIRE_NAME: &str = "never_ask";
const ASK_ME_WIRE_NAME: &str = "ask_before_risky_actions";

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn approval_choice() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        Just(json!(AUTO_WIRE_NAME)),
        Just(json!(ASK_ME_WIRE_NAME)),
    ]
}

fn approval_policy() -> impl Strategy<Value = &'static str> {
    prop_oneof![Just(AUTO_WIRE_NAME), Just(ASK_ME_WIRE_NAME)]
}

fn listed_workspace_policy(
    device: &TestDevice,
    workspace_id: &str,
) -> Result<Value, String> {
    let views = device.run(&json!({ "command": "list_workspaces" }))?;
    for view in views.as_array().cloned().unwrap_or_default() {
        if view["workspace"]["id"] == json!(workspace_id) {
            return Ok(view["workspace"]["approval_policy"].clone());
        }
    }
    Err(format!("workspace {workspace_id} is not listed"))
}

#[test]
fn test_list_workspaces_shows_a_new_workspace_on_auto() {
    let prepared = prepared_or_panic();

    let policy =
        listed_workspace_policy(&prepared.device, &prepared.workspace_id);

    assert_eq!(policy, Ok(json!(AUTO_WIRE_NAME)));
}

#[test]
fn test_create_project_follows_the_workspace_when_no_choice_is_sent() {
    let prepared = prepared_or_panic();

    let project = prepared
        .device
        .run(&create_project_command(&prepared.workspace_id));

    assert_eq!(
        project.map(|created| created["approval_policy"].clone()),
        Ok(Value::Null)
    );
}

#[test]
fn test_change_workspace_approval_policy_property_the_list_shows_it() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(SETTING_CASES));

    let outcome = runner.run(&approval_policy(), |policy| {
        let changed = device
            .run(&json!({
                "command": "change_workspace_approval_policy",
                "workspace_id": prepared.workspace_id,
                "approval_policy": policy,
            }))
            .map_err(fail)?;

        let listed = listed_workspace_policy(device, &prepared.workspace_id)
            .map_err(fail)?;
        prop_assert_eq!(&changed["approval_policy"], &json!(policy));
        prop_assert_eq!(&changed["id"], &json!(prepared.workspace_id));
        prop_assert_eq!(listed, json!(policy));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_create_project_property_keeps_the_chosen_approval_policy() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(SETTING_CASES));

    let outcome = runner.run(&approval_choice(), |choice| {
        let mut command = create_project_command(&prepared.workspace_id);
        command["name"] = json!(format!("shop-{}", choice.is_null()));
        command["approval_policy"] = choice.clone();
        let created = device.run(&command).map_err(fail)?;
        let project_id = read_text(&created, "/id").map_err(fail)?;

        let listed = device
            .run(&json!({
                "command": "list_projects",
                "workspace_id": prepared.workspace_id,
            }))
            .map_err(fail)?;
        let stored = listed
            .as_array()
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .find(|view| view["project"]["id"] == json!(project_id))
            .map(|view| view["project"]["approval_policy"].clone());
        prop_assert_eq!(&created["approval_policy"], &choice);
        prop_assert_eq!(stored, Some(choice));
        let _removed = device.run(&json!({
            "command": "delete_project",
            "project_id": project_id,
        }));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_create_task_property_keeps_the_step_choice() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(SETTING_CASES));

    let outcome = runner.run(&approval_choice(), |choice| {
        let mut command = create_task_command(
            &prepared.workspace_id,
            &prepared.project_id,
            "details",
        );
        command["task"]["approval_policy"] = choice.clone();

        let created = device.run(&command).map_err(fail)?;

        prop_assert_eq!(&created["approval_policy"], &choice);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

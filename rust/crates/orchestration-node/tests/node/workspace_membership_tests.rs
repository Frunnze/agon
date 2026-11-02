use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_project_command, create_task_command,
    prepare_workspace,
};
use crate::support::pairing_steps::pair_into_workspace;
use crate::support::test_device::{TestDevice, fail, read_text};

const WORKSPACE_CASES: u32 = 3;
const WORKSPACE_NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,20}";
const SEALED_DETAILS: &str = "details only workspace members can read";

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn held_workspace_ids(device: &TestDevice) -> Result<Vec<Value>, String> {
    let status = device.run(&json!({ "command": "status" }))?;
    let workspaces = status["account"]["workspaces"].as_array();
    let mut workspace_ids = Vec::new();
    for workspace in workspaces.cloned().unwrap_or_default() {
        workspace_ids.push(workspace["id"].clone());
    }
    Ok(workspace_ids)
}

fn listed_workspace(
    device: &TestDevice,
    workspace_id: &Value,
) -> Result<Option<Value>, String> {
    let views = device.run(&json!({ "command": "list_workspaces" }))?;
    for view in views.as_array().cloned().unwrap_or_default() {
        if &view["workspace"]["id"] == workspace_id {
            return Ok(Some(view));
        }
    }
    Ok(None)
}

fn create_sealed_task(
    device: &TestDevice,
    workspace_id: &str,
) -> Result<(), String> {
    let project = device.run(&create_project_command(workspace_id))?;
    let project_id = read_text(&project, "/id")?;
    let task = create_task_command(workspace_id, &project_id, SEALED_DETAILS);
    device.run(&task)?;
    Ok(())
}

fn read_first_task_details(
    device: &TestDevice,
    workspace_id: &str,
) -> Result<Value, String> {
    let tasks = device.run(&json!({
        "command": "list_tasks",
        "workspace_id": workspace_id,
    }))?;
    Ok(tasks["tasks"][0]["task"]["details"].clone())
}

#[test]
fn test_create_workspace_property_the_creator_holds_the_listed_workspace() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(WORKSPACE_CASES));

    let outcome = runner.run(&WORKSPACE_NAME_PATTERN, |name| {
        let created = device
            .run(&json!({ "command": "create_workspace", "name": name }))
            .map_err(fail)?;

        let listed = listed_workspace(device, &created["id"]).map_err(fail)?;
        let held_ids = held_workspace_ids(device).map_err(fail)?;

        prop_assert_eq!(&created["name"], &Value::String(name.clone()));
        let Some(listed) = listed else {
            return Err(fail("the new workspace is not listed"));
        };
        prop_assert_eq!(&listed["workspace"]["name"], &Value::String(name));
        prop_assert_eq!(&listed["project_count"], &json!(0));
        prop_assert!(held_ids.contains(&created["id"]));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_add_device_to_workspace_property_member_sees_it_until_removed() {
    let prepared = prepared_or_panic();
    let Ok(paired_device) = TestDevice::start() else {
        panic!("the second device starts");
    };
    let paired = pair_into_workspace(&prepared, &paired_device);
    let Ok(paired_device_id) = paired else {
        panic!("the second device pairs: {paired:?}");
    };
    let owner = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(WORKSPACE_CASES));

    let outcome = runner.run(&WORKSPACE_NAME_PATTERN, |name| {
        let created = owner
            .run(&json!({ "command": "create_workspace", "name": name }))
            .map_err(fail)?;
        let workspace_id = read_text(&created, "/id").map_err(fail)?;
        create_sealed_task(owner, &workspace_id).map_err(fail)?;
        let membership = json!({
            "workspace_id": workspace_id,
            "device_id": paired_device_id,
        });
        let mut add_command = membership.clone();
        add_command["command"] = json!("add_device_to_workspace");
        let mut remove_command = membership;
        remove_command["command"] = json!("remove_device_from_workspace");

        let before = held_workspace_ids(&paired_device).map_err(fail)?;
        let added = owner.run(&add_command);
        let while_member = held_workspace_ids(&paired_device).map_err(fail)?;
        let details = read_first_task_details(&paired_device, &workspace_id);
        let removed = owner.run(&remove_command);
        let after = held_workspace_ids(&paired_device).map_err(fail)?;

        prop_assert!(!before.contains(&created["id"]));
        prop_assert_eq!(added, Ok(Value::Null));
        prop_assert!(while_member.contains(&created["id"]));
        prop_assert_eq!(details, Ok(json!(SEALED_DETAILS)));
        prop_assert_eq!(removed, Ok(Value::Null));
        prop_assert!(!after.contains(&created["id"]));
        prop_assert!(after.contains(&json!(prepared.workspace_id)));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

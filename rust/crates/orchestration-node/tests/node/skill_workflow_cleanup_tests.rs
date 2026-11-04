use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_skill_command, create_workflow_command,
    prepare_workspace,
};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::fail;

const CLEANUP_CASES: u32 = 3;
const WORKFLOW_TASK: &str = "plan the release";
const CHANGED_TASK: &str = "plan the release, then tell me";

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn create_skill(
    prepared: &PreparedWorkspace,
    instructions: &str,
) -> Result<Value, String> {
    let command = create_skill_command(&prepared.workspace_id, instructions);
    let created = prepared.device.run(&command)?;
    Ok(created["id"].clone())
}

fn create_signed_workflow_using(
    prepared: &PreparedWorkspace,
    skill_id: &Value,
) -> Result<Value, String> {
    let mut command =
        create_workflow_command(&prepared.workspace_id, WORKFLOW_TASK);
    command["agents"][0]["skills"] = json!([skill_id]);
    let created = prepared.device.run(&command)?;
    prepared.device.run(&json!({
        "command": "sign_workflow",
        "workflow_id": created["workflow"]["id"],
    }))
}

fn save_unsigned_change(
    prepared: &PreparedWorkspace,
    signed: &Value,
) -> Result<Value, String> {
    let mut changed_workflow = signed["workflow"].clone();
    changed_workflow["agents"][0]["task"] = json!(CHANGED_TASK);
    prepared.device.run(&json!({
        "command": "save_workflow",
        "workspace_id": prepared.workspace_id,
        "workflow": changed_workflow,
    }))
}

fn delete_skill(
    prepared: &PreparedWorkspace,
    skill_id: &Value,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "delete_skill",
        "skill_id": skill_id,
    }))
}

fn find_listed_workflow(
    prepared: &PreparedWorkspace,
    workflow_id: &Value,
) -> Result<Value, String> {
    let workflows = prepared.device.run(&json!({
        "command": "list_workflows",
        "workspace_id": prepared.workspace_id,
    }))?;
    let entries = workflows.as_array().cloned().unwrap_or_default();
    entries
        .into_iter()
        .find(|entry| &entry["workflow"]["id"] == workflow_id)
        .ok_or_else(|| "the workflow is not listed".to_string())
}

#[test]
fn test_delete_skill_property_signed_workflows_drop_it_and_stay_signed() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(CLEANUP_CASES));

    let outcome = runner.run(&secret_text_strategy(), |instructions| {
        let skill_id = create_skill(&prepared, &instructions).map_err(fail)?;
        let signed = create_signed_workflow_using(&prepared, &skill_id)
            .map_err(fail)?;
        let workflow_id = signed["workflow"]["id"].clone();

        delete_skill(&prepared, &skill_id).map_err(fail)?;
        let listed =
            find_listed_workflow(&prepared, &workflow_id).map_err(fail)?;

        prop_assert_eq!(
            &listed["workflow"]["agents"][0]["skills"],
            &json!([])
        );
        prop_assert_eq!(&listed["signature_state"], "signed");
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_delete_skill_property_unsigned_changes_are_never_signed_for_you() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(CLEANUP_CASES));

    let outcome = runner.run(&secret_text_strategy(), |instructions| {
        let skill_id = create_skill(&prepared, &instructions).map_err(fail)?;
        let signed = create_signed_workflow_using(&prepared, &skill_id)
            .map_err(fail)?;
        let workflow_id = signed["workflow"]["id"].clone();
        save_unsigned_change(&prepared, &signed).map_err(fail)?;

        delete_skill(&prepared, &skill_id).map_err(fail)?;
        let listed =
            find_listed_workflow(&prepared, &workflow_id).map_err(fail)?;

        prop_assert_eq!(
            &listed["workflow"]["agents"][0]["skills"],
            &json!([])
        );
        prop_assert_eq!(
            &listed["workflow"]["agents"][0]["task"],
            CHANGED_TASK
        );
        prop_assert_eq!(&listed["signature_state"], "changed_not_signed");
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

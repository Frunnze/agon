use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, prepare_workspace, two_step_workflow_command,
};
use crate::support::test_device::fail;

const RESAVE_CASES: u32 = 4;
const STEP_TASK_PATTERN: &str = "[A-Z][a-z ]{0,30}";

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn create_signed_workflow(
    prepared: &PreparedWorkspace,
    plan_task: &str,
    build_task: &str,
) -> Result<Value, String> {
    let command = two_step_workflow_command(
        &prepared.workspace_id,
        plan_task,
        build_task,
    );
    let created = prepared.device.run(&command)?;
    prepared.device.run(&json!({
        "command": "sign_workflow",
        "workflow_id": created["workflow"]["id"],
    }))
}

fn save_workflow(
    prepared: &PreparedWorkspace,
    workflow: &Value,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "save_workflow",
        "workspace_id": prepared.workspace_id,
        "workflow": workflow,
    }))
}

#[test]
fn test_save_workflow_property_an_unchanged_save_stays_signed() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(RESAVE_CASES));
    let step_tasks = (STEP_TASK_PATTERN, STEP_TASK_PATTERN);

    let outcome = runner.run(&step_tasks, |(plan_task, build_task)| {
        let signed =
            create_signed_workflow(&prepared, &plan_task, &build_task)
                .map_err(fail)?;

        let saved =
            save_workflow(&prepared, &signed["workflow"]).map_err(fail)?;
        let saved_again =
            save_workflow(&prepared, &saved["workflow"]).map_err(fail)?;

        prop_assert_eq!(&signed["signature_state"], "signed");
        prop_assert_eq!(&saved["signature_state"], "signed");
        prop_assert_eq!(&saved["changes"], &json!([]));
        prop_assert_eq!(&saved_again["signature_state"], "signed");
        prop_assert_eq!(&saved_again["workflow"], &signed["workflow"]);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_save_workflow_property_a_changed_step_text_drops_the_signature() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(RESAVE_CASES));
    let step_tasks = (STEP_TASK_PATTERN, STEP_TASK_PATTERN);

    let outcome = runner.run(&step_tasks, |(build_task, changed_task)| {
        prop_assume!(build_task != changed_task);
        let signed = create_signed_workflow(&prepared, "Plan", &build_task)
            .map_err(fail)?;
        let mut changed_workflow = signed["workflow"].clone();
        changed_workflow["agents"][1]["task"] = json!(changed_task);

        let saved =
            save_workflow(&prepared, &changed_workflow).map_err(fail)?;

        prop_assert_eq!(&saved["signature_state"], "changed_not_signed");
        prop_assert_eq!(&saved["workflow"], &changed_workflow);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

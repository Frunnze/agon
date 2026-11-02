use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_task_command, create_workflow_command,
    prepare_workspace,
};
use crate::support::test_device::{fail, read_text};

const DELETION_CASES: u32 = 3;

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn job_command(prepared: &PreparedWorkspace) -> Value {
    let mut job = create_task_command(
        &prepared.workspace_id,
        &prepared.project_id,
        "nightly",
    );
    job["command"] = json!("create_job");
    job["schedule"] =
        json!({ "every": "day", "at": { "hour": 2, "minute": 0 } });
    if let Some(fields) = job.as_object_mut() {
        fields.remove("start");
    }
    job
}

fn count_listed(
    prepared: &PreparedWorkspace,
    command_name: &str,
    pointer: &str,
) -> Result<usize, String> {
    let listed = prepared.device.run(&json!({
        "command": command_name,
        "workspace_id": prepared.workspace_id,
    }))?;
    Ok(listed
        .pointer(pointer)
        .and_then(Value::as_array)
        .map_or(0, Vec::len))
}

#[test]
fn test_delete_task_property_leaves_no_task_or_job_behind() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(DELETION_CASES));

    let outcome = runner.run(&any::<bool>(), |is_job| {
        let command = if is_job {
            job_command(&prepared)
        } else {
            create_task_command(
                &prepared.workspace_id,
                &prepared.project_id,
                "details",
            )
        };
        let created = device.run(&command).map_err(fail)?;
        let task_id = read_text(&created, "/id").map_err(fail)?;

        let deleted = device
            .run(&json!({ "command": "delete_task", "task_id": task_id }))
            .map_err(fail)?;

        prop_assert_eq!(deleted, Value::Null);
        let task_count =
            count_listed(&prepared, "list_tasks", "/tasks").map_err(fail)?;
        let job_count =
            count_listed(&prepared, "list_jobs", "").map_err(fail)?;
        prop_assert_eq!(task_count + job_count, 0);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn delete_project_removes_the_project_and_its_tasks() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let task = create_task_command(
        &prepared.workspace_id,
        &prepared.project_id,
        "details",
    );
    let created = device.run(&task);
    assert!(created.is_ok(), "{created:?}");

    let deleted = device.run(&json!({
        "command": "delete_project",
        "project_id": prepared.project_id,
    }));

    assert_eq!(deleted, Ok(Value::Null));
    assert_eq!(count_listed(&prepared, "list_projects", ""), Ok(0));
    assert_eq!(count_listed(&prepared, "list_tasks", "/tasks"), Ok(0));
}

#[test]
fn delete_workflow_removes_an_unused_workflow() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let created = device
        .run(&create_workflow_command(&prepared.workspace_id, "Plan it"));
    let Ok(created) = created else {
        panic!("the workflow is created: {created:?}");
    };

    let deleted = device.run(&json!({
        "command": "delete_workflow",
        "workflow_id": created["workflow"]["id"],
    }));

    assert_eq!(deleted, Ok(Value::Null));
    assert_eq!(count_listed(&prepared, "list_workflows", ""), Ok(0));
}

#[test]
fn delete_workspace_removes_one_but_never_the_last() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let created = device
        .run(&json!({ "command": "create_workspace", "name": "personal" }));
    let Ok(created) = created else {
        panic!("the workspace is created: {created:?}");
    };

    let deleted = device.run(&json!({
        "command": "delete_workspace",
        "workspace_id": created["id"],
    }));
    let last = device.run(&json!({
        "command": "delete_workspace",
        "workspace_id": prepared.workspace_id,
    }));
    let listed = device.run(&json!({ "command": "list_workspaces" }));

    assert_eq!(deleted, Ok(Value::Null));
    let last_error = last.err().unwrap_or_default();
    assert!(
        last_error.contains("the last workspace cannot be deleted"),
        "{last_error}"
    );
    let Ok(listed) = listed else {
        panic!("the workspaces are listed: {listed:?}");
    };
    assert_eq!(listed.as_array().map(Vec::len), Some(1));
}

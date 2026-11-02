use orchestration_api::work::RunEvent;
use orchestration_core::run::RunFailure;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::create_workflow_command;
use crate::support::drafting_desk::{
    draft_command, drafted_workflow_json, finish_or_panic, open_desk_or_panic,
    start_or_panic,
};
use crate::support::test_device::{fail, is_defined_reply, read_text};

const DRAFTED_AGENT_TASK: &str = "Plan the whole feature";
const CHANGED_AGENT_TASK: &str = "Plan the whole release";
const DRAFT_CASES: u32 = 12;

#[test]
fn a_finished_draft_is_saved_unsigned_and_returned() {
    let desk = open_desk_or_panic();
    let draft = start_or_panic(&desk, &draft_command(&desk.prepared));
    let drafted =
        drafted_workflow_json(&draft.workflow_id, DRAFTED_AGENT_TASK);
    finish_or_panic(&desk, &draft, &drafted);

    let status = desk.status_reply(&draft);

    assert_eq!(status["ok"]["state"], "done", "{status}");
    let view = &status["ok"]["workflow"];
    assert_eq!(view["workflow"]["id"], Value::String(draft.workflow_id));
    assert_eq!(view["workflow"]["agents"][0]["task"], DRAFTED_AGENT_TASK);
    assert_eq!(view["signature_state"], "not_signed_yet");
    let Ok(workflows) = desk.list_workflows() else {
        panic!("the workflows are listed");
    };
    assert_eq!(workflows.as_array().map(Vec::len), Some(1));
    assert_eq!(desk.count_task_runs(&draft.task_id), Ok(0));
}

#[test]
fn a_draft_reports_working_until_its_run_finishes() {
    let desk = open_desk_or_panic();
    let draft = start_or_panic(&desk, &draft_command(&desk.prepared));

    let status = desk.status_reply(&draft);

    assert_eq!(status["ok"]["state"], "working", "{status}");
    let Ok(workflows) = desk.list_workflows() else {
        panic!("the workflows are listed");
    };
    assert_eq!(workflows, json!([]));
}

#[test]
fn a_final_message_that_is_not_json_gives_a_defined_error() {
    let desk = open_desk_or_panic();
    let draft = start_or_panic(&desk, &draft_command(&desk.prepared));
    finish_or_panic(&desk, &draft, "I could not draft {it");

    let status = desk.status_reply(&draft);

    assert!(is_defined_reply(&status));
    assert!(status["error"].is_string(), "{status}");
}

#[test]
fn a_draft_for_another_workflow_gives_a_defined_error() {
    let desk = open_desk_or_panic();
    let draft = start_or_panic(&desk, &draft_command(&desk.prepared));
    let other_id = "00000000-0000-0000-0000-000000000077";
    let drafted = drafted_workflow_json(other_id, DRAFTED_AGENT_TASK);
    finish_or_panic(&desk, &draft, &drafted);

    let status = desk.status_reply(&draft);

    assert!(status["error"].is_string(), "{status}");
}

#[test]
fn a_draft_inside_a_code_fence_with_prose_is_accepted() {
    let desk = open_desk_or_panic();
    let draft = start_or_panic(&desk, &draft_command(&desk.prepared));
    let drafted =
        drafted_workflow_json(&draft.workflow_id, DRAFTED_AGENT_TASK);
    let fenced = format!("Here it is:\n```json\n{drafted}\n```\nDone.");
    finish_or_panic(&desk, &draft, &fenced);

    let status = desk.status_reply(&draft);

    assert_eq!(status["ok"]["state"], "done", "{status}");
}

#[test]
fn a_failed_draft_gives_a_defined_error() {
    let desk = open_desk_or_panic();
    let draft = start_or_panic(&desk, &draft_command(&desk.prepared));
    let failed = RunEvent::Failed {
        failure: RunFailure {
            step_name: draft.step_name.clone(),
            runner: None,
            reason: "the agent broke".to_owned(),
            retry_runs_on_same_runner: true,
        },
    };
    let Ok(()) = desk.post(&draft, vec![failed]) else {
        panic!("the failure is posted");
    };

    let status = desk.status_reply(&draft);

    let error = status["error"].as_str().unwrap_or_default();
    assert!(error.contains("the agent broke"), "{status}");
    assert_eq!(desk.count_task_runs(&draft.task_id), Ok(0));
}

#[test]
fn a_stopped_draft_is_left_for_the_app_that_stopped_it_to_remove() {
    let desk = open_desk_or_panic();
    let draft = start_or_panic(&desk, &draft_command(&desk.prepared));
    let cancelled = desk.prepared.device.run(&json!({
        "command": "cancel_run",
        "run_id": draft.run_id.0,
    }));
    assert!(cancelled.is_ok(), "{cancelled:?}");

    let status = desk.status_reply(&draft);
    let runs_after_status = desk.count_task_runs(&draft.task_id);
    let deleted = desk.prepared.device.run(&json!({
        "command": "delete_task",
        "task_id": draft.task_id,
    }));

    let error = status["error"].as_str().unwrap_or_default();
    assert!(error.contains("cancelled"), "{status}");
    assert_eq!(runs_after_status, Ok(1));
    assert!(deleted.is_ok(), "{deleted:?}");
    assert_eq!(desk.count_task_runs(&draft.task_id), Ok(0));
}

#[test]
fn a_changed_workflow_is_saved_as_an_unsigned_change() {
    let desk = open_desk_or_panic();
    let workspace_id = desk.prepared.workspace_id.clone();
    let created = desk
        .prepared
        .device
        .run(&create_workflow_command(&workspace_id, DRAFTED_AGENT_TASK));
    let Ok(workflow_id) =
        created.and_then(|view| read_text(&view, "/workflow/id"))
    else {
        panic!("the workflow is created");
    };
    let Ok(_) = desk.sign(&workflow_id) else {
        panic!("the workflow is signed");
    };
    let change = json!({
        "command": "change_workflow",
        "workspace_id": workspace_id,
        "workflow_id": workflow_id,
        "request": "Plan the release instead",
    });
    let draft = start_or_panic(&desk, &change);
    let changed = drafted_workflow_json(&workflow_id, CHANGED_AGENT_TASK);
    finish_or_panic(&desk, &draft, &changed);

    let status = desk.status_reply(&draft);

    let view = &status["ok"]["workflow"];
    assert_eq!(view["signature_state"], "changed_not_signed", "{status}");
    assert!(view["changes"].to_string().contains(CHANGED_AGENT_TASK));
}

#[test]
fn test_workflow_draft_status_property_any_final_message_gets_a_defined_reply()
{
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DRAFT_CASES));
    let final_messages = prop_oneof![
        "\\PC{1,200}",
        Just(String::from("{}")),
        Just(String::from("{\"id\": 7}")),
    ];

    let outcome = runner.run(&final_messages, |final_message| {
        let draft =
            desk.start(&draft_command(&desk.prepared)).map_err(fail)?;
        desk.finish(&draft, &final_message).map_err(fail)?;

        let status = desk.status_reply(&draft);

        prop_assert!(is_defined_reply(&status));
        if let Some(success) = status.get("ok") {
            prop_assert_eq!(&success["state"], "done");
            let drafted_id = &success["workflow"]["workflow"]["id"];
            let expected_id = Value::String(draft.workflow_id.clone());
            prop_assert_eq!(drafted_id, &expected_id);
        }
        let run_count = desk.count_task_runs(&draft.task_id).map_err(fail)?;
        prop_assert_eq!(run_count, 0);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::support::command_builders::prepare_workspace;
use crate::support::drafting_desk::{DraftingDesk, open_desk_or_panic};
use crate::support::git_folders::create_git_folder;
use crate::support::item_drafting_desk::{
    StartedItemDraft, draft_item_command, drafted_kind_strategy,
    drafted_project_answer, drafted_task_answer, fail_item_draft,
    finish_item_draft, item_draft_status, read_device_id, start_item_draft,
};
use crate::support::test_device::{fail, is_defined_reply};

const FINAL_MESSAGE_CASES: u32 = 8;
const FOREIGN_PROJECT_ID: &str = "00000000-0000-0000-0000-0000deadbeef";

fn start_or_panic(desk: &DraftingDesk, command: &Value) -> StartedItemDraft {
    match start_item_draft(desk, command) {
        Ok(draft) => draft,
        Err(message) => panic!("the item draft starts: {message}"),
    }
}

fn finish_or_panic(desk: &DraftingDesk, draft: &StartedItemDraft, text: &str) {
    if let Err(message) = finish_item_draft(desk, draft, text) {
        panic!("the item draft finishes: {message}");
    }
}

#[test]
fn draft_item_refuses_an_empty_request_or_change_note() {
    let Ok(prepared) = prepare_workspace() else {
        panic!("the workspace is prepared");
    };
    let mut changing = draft_item_command(&prepared, "rule", "No pushes");
    changing["change"] = json!({ "draft": { "title": "x" }, "note": " " });

    let empty_request = prepared
        .device
        .run(&draft_item_command(&prepared, "task", " \n"));
    let empty_note = prepared.device.run(&changing);

    assert_eq!(empty_request, Err("the request cannot be empty".to_owned()));
    assert_eq!(
        empty_note,
        Err("the change note cannot be empty".to_owned())
    );
}

#[test]
fn an_item_draft_reports_working_until_its_run_finishes() {
    let desk = open_desk_or_panic();
    let command = draft_item_command(&desk.prepared, "task", "Ship 2.4");
    let draft = start_or_panic(&desk, &command);

    let status = item_draft_status(&desk, &draft);

    assert_eq!(status, json!({ "ok": { "state": "working" } }));
}

#[test]
fn a_finished_item_draft_is_returned_checked_and_its_task_removed() {
    let desk = open_desk_or_panic();
    let command = draft_item_command(&desk.prepared, "task", "Ship 2.4");
    let draft = start_or_panic(&desk, &command);
    let answer = drafted_task_answer(&desk.prepared.project_id);
    let final_message = format!("Here you go:\n```json\n{answer:#}\n```");
    finish_or_panic(&desk, &draft, &final_message);

    let status = item_draft_status(&desk, &draft);

    let mut expected_draft = answer;
    expected_draft["kind"] = json!("task");
    let expected = json!({
        "ok": { "state": "done", "draft": expected_draft, "problems": [] },
    });
    assert_eq!(status, expected);
    assert_eq!(desk.count_task_runs(&draft.task_id), Ok(0));
}

#[test]
fn an_item_draft_naming_an_unknown_project_carries_the_problem() {
    let desk = open_desk_or_panic();
    let command = draft_item_command(&desk.prepared, "job", "Nightly build");
    let draft = start_or_panic(&desk, &command);
    let mut answer = drafted_task_answer(FOREIGN_PROJECT_ID);
    answer["schedule"] = json!({ "every": "hour", "minute": 5 });
    finish_or_panic(&desk, &draft, &answer.to_string());

    let status = item_draft_status(&desk, &draft);

    assert_eq!(status["ok"]["state"], "done", "{status}");
    assert_eq!(status["ok"]["draft"]["kind"], "job", "{status}");
    let expected = json!(["The agent chose a project that is not in acme."]);
    assert_eq!(status["ok"]["problems"], expected, "{status}");
}

#[test]
fn a_failed_item_draft_gives_its_reason() {
    let desk = open_desk_or_panic();
    let command = draft_item_command(&desk.prepared, "skill", "Release notes");
    let draft = start_or_panic(&desk, &command);
    let Ok(()) = fail_item_draft(&desk, &draft, "the agent broke") else {
        panic!("the failure is posted");
    };

    let status = item_draft_status(&desk, &draft);

    let error = status["error"].as_str().unwrap_or_default();
    assert!(error.contains("the agent broke"), "{status}");
    assert_eq!(desk.count_task_runs(&draft.task_id), Ok(0));
}

#[test]
fn a_project_draft_naming_a_missing_folder_carries_the_folder_problem() {
    let desk = open_desk_or_panic();
    let command = draft_item_command(&desk.prepared, "project", "Billing");
    let draft = start_or_panic(&desk, &command);
    let Ok(parent) = TempDir::new() else {
        panic!("the temporary folder is made");
    };
    let missing_path = format!("{}/missing", parent.path().display());
    let answer = drafted_project_answer(&missing_path);
    finish_or_panic(&desk, &draft, &answer.to_string());

    let status = item_draft_status(&desk, &draft);

    let expected_problem = format!(
        "The folder {missing_path} does not exist or this app cannot open it."
    );
    assert_eq!(status["ok"]["problems"], json!([expected_problem]));
    assert_eq!(status["ok"]["draft"]["repositories"], json!([]));
}

#[test]
fn a_project_draft_naming_a_git_folder_gets_its_local_address() {
    let desk = open_desk_or_panic();
    let command = draft_item_command(&desk.prepared, "project", "Billing");
    let draft = start_or_panic(&desk, &command);
    let Ok(parent) = TempDir::new() else {
        panic!("the temporary folder is made");
    };
    let Ok(folder) = create_git_folder(parent.path(), "main") else {
        panic!("the git folder is made");
    };
    let path = folder.display().to_string();
    let answer = drafted_project_answer(&path);
    finish_or_panic(&desk, &draft, &answer.to_string());
    let Ok(device_id) = read_device_id(&desk.prepared.device) else {
        panic!("the device id is read");
    };

    let status = item_draft_status(&desk, &draft);

    let expected_repositories = json!([{
        "address": format!("local:{device_id}:{path}"),
        "default_branch": "main",
    }]);
    assert_eq!(status["ok"]["problems"], json!([]), "{status}");
    let repositories = &status["ok"]["draft"]["repositories"];
    assert_eq!(repositories, &expected_repositories);
}

#[test]
fn test_item_draft_status_property_any_final_message_gets_a_defined_reply() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(FINAL_MESSAGE_CASES));
    let final_messages = prop_oneof![
        "\\PC{1,200}",
        Just(String::from("{}")),
        Just(String::from("{\"title\": 7}")),
    ];
    let cases = (drafted_kind_strategy(), final_messages);

    let outcome = runner.run(&cases, |(kind, final_message)| {
        let command = draft_item_command(&desk.prepared, kind, "Anything");
        let draft = start_item_draft(&desk, &command).map_err(fail)?;
        finish_item_draft(&desk, &draft, &final_message).map_err(fail)?;

        let status = item_draft_status(&desk, &draft);

        prop_assert!(is_defined_reply(&status), "{}", status);
        if let Some(success) = status.get("ok") {
            prop_assert_eq!(&success["state"], "done");
            prop_assert_eq!(&success["draft"]["kind"], kind);
        }
        let run_count = desk.count_task_runs(&draft.task_id).map_err(fail)?;
        prop_assert_eq!(run_count, 0);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

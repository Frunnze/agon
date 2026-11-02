use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::WorkspaceId;
use orchestration_core::task::{TaskDoer, TaskPlace};
use orchestration_core::workflow::AgentKind;
use proptest::prelude::*;
use serde_json::json;
use uuid::Uuid;

use crate::support::command_builders::PROJECT_NAME;
use crate::support::drafting_desk::open_desk_or_panic;
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::first_project_desk::open_first_project_desk;
use crate::support::item_drafting_desk::{
    draft_item_command, drafted_kind_strategy, drafted_project_answer,
    read_device_id,
};
use crate::support::test_device::{fail, read_text};

const COMMAND_CASES: u32 = 4;
const BILLING_ADDRESS: &str = "github.com/acme/billing";
const FIRST_PROJECT_WISH: &str = "secretbillingrepository";

fn parse_workspace_id(text: &str) -> Result<WorkspaceId, TestCaseError> {
    let parsed = Uuid::parse_str(text).map_err(fail)?;
    Ok(WorkspaceId(parsed))
}

fn contains_text(body: &[u8], text: &str) -> bool {
    String::from_utf8_lossy(body).contains(text)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(COMMAND_CASES))]

    #[test]
    fn test_draft_item_property_queues_a_workspace_task_with_the_request(
        kind in drafted_kind_strategy(),
        request in secret_text_strategy(),
    ) {
        let desk = open_desk_or_panic();
        let prepared = &desk.prepared;
        let device_id = read_device_id(&prepared.device).map_err(fail)?;

        let drafting = prepared
            .device
            .run(&draft_item_command(prepared, kind, &request))
            .map_err(fail)?;
        let assignment = desk.claim_drafting_run().map_err(fail)?;

        let task = &assignment.task;
        let task_id = read_text(&drafting, "/task_id").map_err(fail)?;
        prop_assert_eq!(task.id.0.to_string(), task_id);
        let drafter = read_text(&drafting, "/drafter").map_err(fail)?;
        prop_assert_eq!(drafter, "claude_code");
        prop_assert_eq!(&task.title, &format!("Draft new {kind}"));
        let expected_lines = [
            format!("Draft a new {kind}.\n"),
            format!("Workspace: acme (id {})\n", prepared.workspace_id),
            format!("This computer: air-laptop (id {device_id})\n"),
            format!(
                "Projects:\n- {PROJECT_NAME} (id {}): github.com/acme/app\n",
                prepared.project_id
            ),
            format!("What the person wants:\n{request}\n"),
        ];
        for expected_line in &expected_lines {
            let is_listed = task.details.contains(expected_line.as_str());
            prop_assert!(is_listed, "{}", task.details);
        }
        let expected_doer = TaskDoer::OneAgent {
            agent: AgentKind::ClaudeCode,
        };
        prop_assert_eq!(&task.doer, &expected_doer);
        prop_assert_eq!(&task.runs_on, &RunnerTarget::AnyFreeRunner);
        prop_assert!(task.skills.is_empty());
        prop_assert!(!task.uses_automatic_skills);
        let workspace_id = parse_workspace_id(&prepared.workspace_id)?;
        prop_assert_eq!(task.place, TaskPlace::InWorkspace { workspace_id });
        prop_assert_eq!(assignment.workspace_id, workspace_id);
        prop_assert!(assignment.project.is_none());
        prop_assert!(assignment.skills.is_empty());
        prop_assert!(assignment.rules.is_empty());
        let is_seen_by_server = prepared
            .server
            .recorded_requests()
            .iter()
            .any(|recorded| contains_text(&recorded.body, &request));
        prop_assert!(!is_seen_by_server);
    }
}

#[test]
fn the_first_project_of_a_workspace_is_drafted_like_any_other() {
    let Ok(first) = open_first_project_desk() else {
        panic!("the workspace without projects is prepared");
    };
    let drafting = first.device.run(&json!({
        "command": "draft_item",
        "workspace_id": first.workspace_id,
        "kind": "project",
        "request": FIRST_PROJECT_WISH,
        "started_from": null,
    }));
    let Ok(drafting) = drafting else {
        panic!("the draft starts: {drafting:?}");
    };
    let Ok(task_id) = read_text(&drafting, "/task_id") else {
        panic!("the drafting task is named: {drafting}");
    };
    let Ok(assignment) = first.claim() else {
        panic!("a member runner takes the drafting run");
    };
    let answer = drafted_project_answer(BILLING_ADDRESS);
    let Ok(()) = first.finish(assignment.run.id, &answer.to_string()) else {
        panic!("the draft finishes");
    };

    let status = first.device.send(&json!({
        "command": "item_draft_status",
        "workspace_id": first.workspace_id,
        "task_id": task_id,
        "kind": "project",
    }));

    assert!(assignment.project.is_none(), "{assignment:?}");
    let details = &assignment.task.details;
    assert!(details.contains("Projects:\n- none\n"), "{details}");
    let is_seen_by_server = first
        .server
        .recorded_requests()
        .iter()
        .any(|recorded| contains_text(&recorded.body, FIRST_PROJECT_WISH));
    assert!(!is_seen_by_server);
    assert_eq!(status["ok"]["state"], "done", "{status}");
    assert_eq!(status["ok"]["draft"]["name"], "billing", "{status}");
    assert_eq!(status["ok"]["problems"], json!([]), "{status}");
}

use orchestration_api::work::RunAssignment;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::task::{TaskDoer, TaskPlace};
use orchestration_core::workflow::AgentKind;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::command_builders::create_workflow_command;
use crate::support::drafting_desk::{DraftingDesk, open_desk_or_panic};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::{fail, read_text};
use crate::support::test_server::RecordedRequest;

const AGENT_TASK_CASES: u32 = 4;
const AGENT_KINDS: [(AgentKind, &str); 3] = [
    (AgentKind::ClaudeCode, "claude_code"),
    (AgentKind::Codex, "codex"),
    (AgentKind::GeminiCli, "gemini_cli"),
];
const PLANNING_AGENT_ID: &str = "00000000-0000-0000-0000-000000000011";
const UNKNOWN_AGENT_ID: &str = "00000000-0000-0000-0000-000000000099";
const CANVAS_UNITS: &str = "position is in canvas pixels";
const WORKFLOW_FIELD_FORMS: [&str; 8] = [
    "{\"kind\": \"any_free_runner\"}",
    "ask_before_risky_actions",
    "never_ask",
    "{\"horizontal\": ",
    "\"step_kind\": \"person\"",
    "\"condition\": \"<outcome>\"",
    "\"round_limit\": 1 to 10",
    "OUTCOME: <outcome>",
];

fn is_task_upload(request: &RecordedRequest) -> bool {
    request.method == "POST" && request.path == "/tasks"
}

fn contains_text(body: &[u8], text: &str) -> bool {
    String::from_utf8_lossy(body).contains(text)
}

fn is_workspace_task(desk: &DraftingDesk, assignment: &RunAssignment) -> bool {
    let workspace_id = assignment.workspace_id;
    let is_this_workspace =
        workspace_id.0.to_string() == desk.prepared.workspace_id;
    let is_placed_there =
        assignment.task.place == TaskPlace::InWorkspace { workspace_id };
    is_this_workspace && is_placed_there && assignment.project.is_none()
}

fn create_planning_workflow(desk: &DraftingDesk) -> Result<String, String> {
    let workflow = desk.prepared.device.run(&create_workflow_command(
        &desk.prepared.workspace_id,
        "Plan the feature",
    ))?;
    read_text(&workflow, "/workflow/id")
}

fn agent_kind_strategy() -> impl Strategy<Value = (AgentKind, &'static str)> {
    proptest::sample::select(AGENT_KINDS.to_vec())
}

fn change_workflow(
    desk: &DraftingDesk,
    workflow_id: &str,
    change_request: &str,
    agent_name: &str,
) -> Result<Value, String> {
    desk.prepared.device.run(&json!({
        "command": "change_workflow",
        "workspace_id": desk.prepared.workspace_id,
        "workflow_id": workflow_id,
        "request": change_request,
        "agent": agent_name,
    }))
}

fn fill_agent_settings(
    desk: &DraftingDesk,
    workflow_id: &str,
    agent_id: &str,
) -> Result<Value, String> {
    desk.prepared.device.run(&json!({
        "command": "fill_agent_settings",
        "workspace_id": desk.prepared.workspace_id,
        "workflow_id": workflow_id,
        "agent_id": agent_id,
    }))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(AGENT_TASK_CASES))]

    #[test]
    fn test_draft_workflow_property_queues_a_workspace_task_to_fill_it_all(
        description in secret_text_strategy(),
    ) {
        let desk = open_desk_or_panic();
        let workspace_id = desk.prepared.workspace_id.clone();

        let drafting = desk.prepared.device.run(&json!({
            "command": "draft_workflow",
            "workspace_id": workspace_id,
            "description": description,
        }))
        .map_err(fail)?;
        let assignment = desk.claim_drafting_run().map_err(fail)?;

        let workflow_id = read_text(&drafting, "/workflow_id").map_err(fail)?;
        let task_id = read_text(&drafting, "/task_id").map_err(fail)?;
        prop_assert_eq!(assignment.task.id.0.to_string(), task_id);
        prop_assert_eq!(&drafting["drafter"], "claude_code");
        let details = &assignment.task.details;
        let this_workspace_only = json!({
            "kind": "only_workspaces",
            "workspaces": [workspace_id],
        })
        .to_string();
        let expected_parts = [
            "Draft a new workflow.\n".to_owned(),
            format!("Workflow id: {workflow_id}\n"),
            format!("Workspace: acme (id {workspace_id})\n"),
            format!("What it should do:\n{description}\n"),
            this_workspace_only,
            CANVAS_UNITS.to_owned(),
        ];
        for expected_part in &expected_parts {
            let is_written = details.contains(expected_part.as_str());
            prop_assert!(is_written, "{}", details);
        }
        for field_form in WORKFLOW_FIELD_FORMS {
            prop_assert!(details.contains(field_form), "{}", details);
        }
        let expected_doer = TaskDoer::OneAgent {
            agent: AgentKind::ClaudeCode,
        };
        prop_assert_eq!(&assignment.task.doer, &expected_doer);
        prop_assert_eq!(&assignment.task.title, "Draft new workflow");
        prop_assert!(is_workspace_task(&desk, &assignment));
        prop_assert_eq!(
            assignment.task.approval_policy,
            Some(ApprovalPolicy::NeverAsk)
        );
        let recorded = desk.prepared.server.recorded_requests();
        let task_upload = recorded.iter().find(|request| {
            is_task_upload(request)
        });
        let upload_body = task_upload
            .map(|request| request.body.clone())
            .unwrap_or_default();
        let upload_json: Value =
            serde_json::from_slice(&upload_body).map_err(fail)?;
        prop_assert_eq!(&upload_json["start"], "now");
        let is_seen_by_server = recorded
            .iter()
            .any(|request| contains_text(&request.body, &description));
        prop_assert!(!is_seen_by_server);
    }

    #[test]
    fn test_change_workflow_property_queues_the_request_and_workflow(
        change_request in secret_text_strategy(),
        (_, agent_name) in agent_kind_strategy(),
    ) {
        let desk = open_desk_or_panic();
        let workflow_id = create_planning_workflow(&desk).map_err(fail)?;

        change_workflow(&desk, &workflow_id, &change_request, agent_name)
            .map_err(fail)?;
        let assignment = desk.claim_drafting_run().map_err(fail)?;

        let details = &assignment.task.details;
        prop_assert!(details.contains(change_request.as_str()));
        prop_assert!(details.contains("Plan the feature"));
        prop_assert!(details.contains(CANVAS_UNITS));
        prop_assert_eq!(&assignment.task.title, "Change workflow release");
        prop_assert!(is_workspace_task(&desk, &assignment));
        prop_assert_eq!(
            assignment.task.approval_policy,
            Some(ApprovalPolicy::NeverAsk)
        );
    }

    #[test]
    fn test_change_workflow_property_runs_the_chosen_agent(
        change_request in secret_text_strategy(),
        (agent, agent_name) in agent_kind_strategy(),
    ) {
        let desk = open_desk_or_panic();
        let workflow_id = create_planning_workflow(&desk).map_err(fail)?;

        let changing =
            change_workflow(&desk, &workflow_id, &change_request, agent_name)
                .map_err(fail)?;
        let assignment = desk.claim_drafting_run().map_err(fail)?;

        prop_assert_eq!(&changing["drafter"], agent_name);
        prop_assert_eq!(
            &assignment.task.doer,
            &TaskDoer::OneAgent { agent }
        );
        let queued_task_id = assignment.task.id.0.to_string();
        prop_assert_eq!(
            changing["task_id"].as_str(),
            Some(queued_task_id.as_str())
        );
    }

    #[test]
    fn test_change_workflow_property_refuses_a_request_without_an_agent(
        change_request in secret_text_strategy(),
    ) {
        let desk = open_desk_or_panic();
        let workflow_id = create_planning_workflow(&desk).map_err(fail)?;
        let uploads_before = desk
            .prepared
            .server
            .recorded_requests()
            .iter()
            .filter(|request| is_task_upload(request))
            .count();

        let refused = desk.prepared.device.run(&json!({
            "command": "change_workflow",
            "workspace_id": desk.prepared.workspace_id,
            "workflow_id": workflow_id,
            "request": change_request,
        }));

        prop_assert!(refused.is_err());
        let uploads_after = desk
            .prepared
            .server
            .recorded_requests()
            .iter()
            .filter(|request| is_task_upload(request))
            .count();
        prop_assert_eq!(uploads_after, uploads_before);
    }

    #[test]
    fn test_change_workflow_property_refuses_an_unknown_agent(
        change_request in secret_text_strategy(),
        unknown_agent_name in "[a-z]{3,10}_agent",
    ) {
        let desk = open_desk_or_panic();
        let workflow_id = create_planning_workflow(&desk).map_err(fail)?;

        let refused = change_workflow(
            &desk,
            &workflow_id,
            &change_request,
            &unknown_agent_name,
        );

        prop_assert!(refused.is_err());
    }
}

#[test]
fn fill_agent_settings_queues_a_workspace_task_naming_the_agent() {
    let desk = open_desk_or_panic();
    let Ok(workflow_id) = create_planning_workflow(&desk) else {
        panic!("the workflow is created");
    };

    let filling = fill_agent_settings(&desk, &workflow_id, PLANNING_AGENT_ID);

    let Ok(filling) = filling else {
        panic!("filling answers: {filling:?}");
    };
    assert_eq!(filling["drafter"], "claude_code");
    assert_eq!(filling["workflow_id"], Value::String(workflow_id));
    let Ok(assignment) = desk.claim_drafting_run() else {
        panic!("a member runner takes the filling run");
    };
    assert_eq!(assignment.task.title, "Fill in agent plan of release");
    assert!(is_workspace_task(&desk, &assignment), "{assignment:?}");
    assert_eq!(
        assignment.task.approval_policy,
        Some(ApprovalPolicy::NeverAsk)
    );
}

#[test]
fn fill_agent_settings_for_an_unknown_agent_gives_a_defined_error() {
    let desk = open_desk_or_panic();
    let Ok(workflow_id) = create_planning_workflow(&desk) else {
        panic!("the workflow is created");
    };

    let filling = fill_agent_settings(&desk, &workflow_id, UNKNOWN_AGENT_ID);

    assert!(filling.is_err());
}

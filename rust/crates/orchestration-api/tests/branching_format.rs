#![allow(clippy::expect_used)]

use orchestration_api::updates::ApiErrorBody;
use orchestration_api::work::{AnswerPersonStepRequest, RunEvent};
use orchestration_core::run::{Run, StepStatus};
use orchestration_core::workflow::{AgentConnection, StepKind, WorkflowAgent};
use proptest::prelude::*;

const OLD_AGENT_JSON: &str = r#"{
    "id": "00000000-0000-0000-0000-000000000001",
    "name": "plan",
    "kind": "claude_code",
    "task": "sealed",
    "runs_on": {"kind": "any_free_runner"},
    "skills": [],
    "uses_automatic_skills": false,
    "approval_policy": "never_ask",
    "position": {"horizontal": 0.0, "vertical": 0.0}
}"#;
const OLD_CONNECTION_JSON: &str = r#"{
    "from": "00000000-0000-0000-0000-000000000001",
    "to": "00000000-0000-0000-0000-000000000002"
}"#;
const OLD_RUN_JSON: &str = r#"{
    "id": "00000000-0000-0000-0000-000000000003",
    "task_id": "00000000-0000-0000-0000-000000000004",
    "number": 1,
    "status": "running",
    "steps": [{
        "name": "plan",
        "agent_id": null,
        "runner": null,
        "status": "waiting_for_person",
        "started_at": null,
        "finished_at": null,
        "result": null
    }],
    "log": [],
    "chat": [],
    "failure": null,
    "link": "direct",
    "link_lost_at": null,
    "agent_session": null,
    "worktree_branch": null,
    "started_by": "laptop",
    "started_at": "2026-11-03T10:00:00Z",
    "finished_at": null
}"#;
const OLD_RESULT_EVENT_JSON: &str =
    r#"{"kind": "step_result_recorded", "step_name": "plan", "result": "x"}"#;

#[test]
fn old_workflow_json_reads_as_agent_steps_and_plain_connections() {
    let agent: WorkflowAgent =
        serde_json::from_str(OLD_AGENT_JSON).expect("old agent decodes");
    let connection: AgentConnection =
        serde_json::from_str(OLD_CONNECTION_JSON)
            .expect("old connection decodes");

    assert_eq!(agent.step_kind, StepKind::Agent);
    assert_eq!(connection.condition, None);
    assert_eq!(connection.round_limit, None);
}

#[test]
fn old_run_json_reads_with_empty_rounds_and_notes() {
    let run: Run = serde_json::from_str(OLD_RUN_JSON).expect("run decodes");

    assert_eq!(run.steps[0].status, StepStatus::WaitingForPerson);
    assert_eq!(run.steps[0].outcome, None);
    assert_eq!(run.steps[0].earlier_rounds, Vec::new());
    assert_eq!(run.loop_rounds, Vec::new());
    assert_eq!(run.notes, Vec::new());
}

#[test]
fn an_old_result_event_reads_without_an_outcome() {
    let event: RunEvent =
        serde_json::from_str(OLD_RESULT_EVENT_JSON).expect("event decodes");

    let RunEvent::StepResultRecorded { outcome, .. } = event else {
        panic!("the event is a step result");
    };
    assert_eq!(outcome, None);
}

proptest! {
    #[test]
    fn test_answer_person_step_request_property_survives_json(
        answer in "\\PC{0,80}",
        choice in proptest::option::of("[a-z][a-z0-9 -]{0,20}"),
    ) {
        let request = AnswerPersonStepRequest { answer, choice };

        let encoded = serde_json::to_string(&request)?;
        let decoded: AnswerPersonStepRequest = serde_json::from_str(&encoded)?;

        prop_assert_eq!(decoded, request);
    }

    #[test]
    fn test_api_error_body_property_lists_choices_only_when_present(
        message in "\\PC{0,40}",
        choices in proptest::collection::vec("[a-z]{1,8}", 0..4),
    ) {
        let body = ApiErrorBody { message, choices: choices.clone() };

        let encoded = serde_json::to_value(&body)?;

        prop_assert_eq!(encoded.get("choices").is_some(), !choices.is_empty());
        let decoded: ApiErrorBody = serde_json::from_value(encoded)?;
        prop_assert_eq!(decoded, body);
    }
}

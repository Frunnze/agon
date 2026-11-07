use std::sync::Arc;
use std::time::Duration;

use chrono::Utc;
use orchestration_api::work::{
    CreateApprovalRequest, RunEvent, RunEventsRequest,
};
use orchestration_core::approval::{ApprovalAction, ApprovalDecision};
use orchestration_core::identifiers::{RunId, generate_uuid};
use orchestration_core::run::{ChatAuthor, ChatMessage, LogLine};
use orchestration_runner::runner_server::RunnerServer;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{
    create_rule_command, create_skill_command, prepare_workspace,
};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::runner_access::{
    ClaimedRun, claim_started_task, started_task_command,
};
use crate::support::test_device::{describe, fail, read_text};
use crate::support::waiting::wait_for;

const TASK_DETAILS: &str = "task details only devices can read";
const SKILL_INSTRUCTIONS: &str = "skill instructions only devices can read";
const RULE_DETAILS: &str = "rule details only devices can read";
const LOG_TEXT: &str = "log text only devices can read";
const AGENT_TEXT: &str = "agent text only devices can read";
const USER_TEXT: &str = "user text only devices can read";
const STEP_NAME: &str = "agent";
const APPROVAL_LIMIT: Duration = Duration::from_secs(20);
const SEALING_CASES: u32 = 8;

fn claim_a_run() -> Result<ClaimedRun, String> {
    let prepared = prepare_workspace()?;
    let workspace_id = prepared.workspace_id.clone();
    prepared
        .device
        .run(&create_skill_command(&workspace_id, SKILL_INSTRUCTIONS))?;
    prepared
        .device
        .run(&create_rule_command(&workspace_id, RULE_DETAILS))?;
    let task_command = started_task_command(&prepared, TASK_DETAILS);
    claim_started_task(prepared, &task_command)
}

fn claim_or_panic() -> ClaimedRun {
    match claim_a_run() {
        Ok(claimed) => claimed,
        Err(message) => panic!("a run is claimed: {message}"),
    }
}

fn log_event(text: &str) -> RunEvent {
    RunEvent::LogAppended {
        line: LogLine {
            at: Utc::now(),
            step_name: STEP_NAME.to_owned(),
            text: text.to_owned(),
            is_error: false,
        },
    }
}

fn agent_chat_event(text: &str) -> RunEvent {
    RunEvent::ChatAppended {
        message: ChatMessage {
            at: Utc::now(),
            author: ChatAuthor::Agent,
            text: text.to_owned(),
            is_error: false,
            waiting_to_send: false,
        },
    }
}

fn post_events(
    claimed: &ClaimedRun,
    events: Vec<RunEvent>,
) -> Result<(), String> {
    let request = RunEventsRequest { events };
    let run_id = claimed.assignment.run.id;
    let posting = claimed.runner.post_run_events(run_id, &request);
    claimed.runtime.block_on(posting).map_err(describe)
}

fn show_run(claimed: &ClaimedRun) -> Result<Value, String> {
    claimed.prepared.device.run(&json!({
        "command": "show_run",
        "run_id": claimed.assignment.run.id,
    }))
}

fn send_user_message(claimed: &ClaimedRun) -> Result<Value, String> {
    claimed.prepared.device.run(&json!({
        "command": "send_chat_message",
        "workspace_id": claimed.prepared.workspace_id,
        "run_id": claimed.assignment.run.id,
        "text": USER_TEXT,
    }))
}

fn push_request(claimed: &ClaimedRun) -> CreateApprovalRequest {
    CreateApprovalRequest {
        run_id: Some(claimed.assignment.run.id),
        action: ApprovalAction::PushCommits {
            repository: "github.com/acme/app".to_owned(),
            branch: "agent/ship".to_owned(),
            commits: vec!["Ship it".to_owned()],
        },
    }
}

fn decide_waiting_approval(claimed: &ClaimedRun) -> Result<(), String> {
    let device = &claimed.prepared.device;
    let approval_id = wait_for(APPROVAL_LIMIT, "the approval", || {
        let approvals = device.run(&json!({ "command": "list_approvals" }))?;
        let first_waiting = read_text(&approvals, "/approvals/0/approval/id");
        Ok(first_waiting.ok())
    })?;
    device.run(&json!({
        "command": "decide_approval",
        "approval_id": approval_id,
        "decision": "approved",
    }))?;
    Ok(())
}

#[test]
fn a_claimed_run_shows_plaintext_task_skill_and_rule_text() {
    let claimed = claim_or_panic();

    let assignment = &claimed.assignment;

    assert_eq!(assignment.task.details, TASK_DETAILS);
    assert_eq!(assignment.skills[0].instructions, SKILL_INSTRUCTIONS);
    assert_eq!(assignment.rules[0].details, RULE_DETAILS);
}

#[test]
fn posted_log_and_chat_are_sealed_on_the_server_and_open_for_clients() {
    let claimed = claim_or_panic();
    let events = vec![log_event(LOG_TEXT), agent_chat_event(AGENT_TEXT)];

    let posted = post_events(&claimed, events);

    assert_eq!(posted, Ok(()));
    let Ok(stored_state) = claimed.prepared.server.read_stored_state() else {
        panic!("the server state is readable");
    };
    assert!(!stored_state.contains(LOG_TEXT));
    assert!(!stored_state.contains(AGENT_TEXT));
    let Ok(shown) = show_run(&claimed) else {
        panic!("the run is shown");
    };
    assert_eq!(shown["run"]["log"][0]["text"], LOG_TEXT);
    assert_eq!(shown["run"]["chat"][0]["text"], AGENT_TEXT);
}

#[test]
fn user_messages_reach_the_runner_in_plaintext_without_agent_messages() {
    let claimed = claim_or_panic();
    let Ok(()) = post_events(&claimed, vec![agent_chat_event(AGENT_TEXT)])
    else {
        panic!("the agent message is posted");
    };
    let Ok(_) = send_user_message(&claimed) else {
        panic!("the user message is sent");
    };

    let reading = claimed.runner.read_user_messages(claimed.assignment.run.id);
    let user_messages = claimed.runtime.block_on(reading);

    let Ok(user_messages) = user_messages else {
        panic!("the user messages are read: {user_messages:?}");
    };
    assert_eq!(user_messages.len(), 1);
    assert_eq!(user_messages[0].text, USER_TEXT);
    assert_eq!(user_messages[0].author, ChatAuthor::You);
}

#[test]
fn test_read_whether_stopped_property_a_cancelled_run_reads_as_stopped() {
    let claimed = claim_or_panic();
    let run_id = claimed.assignment.run.id;
    let before = claimed
        .runtime
        .block_on(claimed.runner.is_run_stopped(run_id));

    let cancelled = claimed.prepared.device.run(&json!({
        "command": "cancel_run",
        "run_id": run_id,
    }));
    let after = claimed
        .runtime
        .block_on(claimed.runner.is_run_stopped(run_id));

    assert!(cancelled.is_ok(), "{cancelled:?}");
    assert_eq!(before, Ok(false));
    assert_eq!(after, Ok(true));
}

#[test]
fn an_approval_decided_by_the_client_reaches_the_runner() {
    let claimed = claim_or_panic();
    let runner = Arc::clone(&claimed.runner);
    let request = push_request(&claimed);
    let waiting = claimed.runtime.spawn(async move {
        runner.request_approval_decision(&request).await
    });

    let decided = decide_waiting_approval(&claimed);
    let decision = claimed.runtime.block_on(waiting);

    assert_eq!(decided, Ok(()));
    let Ok(decision) = decision else {
        panic!("the waiting task ends");
    };
    assert_eq!(decision, Ok(ApprovalDecision::Approved));
}

#[test]
fn events_for_a_run_this_runner_never_claimed_give_a_defined_error() {
    let claimed = claim_or_panic();
    let unknown_run = RunId(generate_uuid());
    let request = RunEventsRequest {
        events: vec![log_event(LOG_TEXT)],
    };

    let posting = claimed.runner.post_run_events(unknown_run, &request);
    let posted = claimed.runtime.block_on(posting);

    let Err(problem) = posted else {
        panic!("posting for an unknown run fails");
    };
    assert!(problem.reason.contains("claimed run"), "{problem}");
}

#[test]
fn test_post_run_events_property_log_text_is_sealed_and_round_trips() {
    let claimed = claim_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SEALING_CASES));

    let outcome = runner.run(&secret_text_strategy(), |log_text| {
        post_events(&claimed, vec![log_event(&log_text)]).map_err(fail)?;

        let stored_state =
            claimed.prepared.server.read_stored_state().map_err(fail)?;
        prop_assert!(!stored_state.contains(&log_text));
        let shown = show_run(&claimed).map_err(fail)?;
        let log_texts = shown["run"]["log"].to_string();
        prop_assert!(log_texts.contains(&log_text));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

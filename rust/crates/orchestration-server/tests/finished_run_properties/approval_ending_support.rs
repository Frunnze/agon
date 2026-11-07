use axum::http::StatusCode;
use orchestration_api::work::{CreateApprovalRequest, DecideApprovalRequest};
use orchestration_core::approval::{
    ApprovalAction, ApprovalDecision, ApprovalRequest,
};
use orchestration_core::run::{Run, StepStatus};
use orchestration_security::decisions::sign_decision;
use orchestration_security::identity::DeviceIdentity;
use proptest::prelude::*;

use crate::finished_run_support::{
    cancel_run, failure_events, post_run_events, step_events,
};
use crate::run_fixtures::{ClaimedRun, start_claimed_run};
use crate::test_client::TestServer;

pub const SUMMARY_PATTERN: &str = "[A-Za-z ]{1,30}";
const FAILURE_REASON: &str = "the agent stopped";

#[derive(Clone, Copy, Debug)]
pub enum RunEnding {
    Cancelled,
    Failed,
}

pub fn run_ending() -> impl Strategy<Value = RunEnding> {
    prop_oneof![Just(RunEnding::Cancelled), Just(RunEnding::Failed)]
}

pub fn choose_decision(is_approved: bool) -> ApprovalDecision {
    if is_approved {
        return ApprovalDecision::Approved;
    }
    ApprovalDecision::Denied
}

pub async fn end_run(
    test: &TestServer,
    claimed: &ClaimedRun,
    ending: RunEnding,
) {
    let owner = &claimed.account.owner;
    let step_name = claimed.run.steps[0].name.clone();
    let response = match ending {
        RunEnding::Cancelled => cancel_run(test, owner, &claimed.run).await,
        RunEnding::Failed => {
            let events = failure_events(&step_name, FAILURE_REASON);
            post_run_events(test, &claimed.holder, &claimed.run, events).await
        }
    };
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
}

fn run_command_action(summary: &str) -> ApprovalAction {
    ApprovalAction::RunCommand {
        tool: "Bash".to_owned(),
        summary: summary.to_owned(),
        command: "npm test".to_owned(),
    }
}

async fn ask_for_approval(
    test: &TestServer,
    runner: &DeviceIdentity,
    run: &Run,
    action: ApprovalAction,
) -> ApprovalRequest {
    let request = CreateApprovalRequest {
        run_id: Some(run.id),
        action,
    };
    let response = test.post(runner, "/approvals", &request).await;
    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    response.json()
}

pub async fn ask_during(
    test: &TestServer,
    claimed: &ClaimedRun,
    summary: &str,
) -> ApprovalRequest {
    let step_name = claimed.run.steps[0].name.clone();
    let waiting = step_events(&step_name, &[StepStatus::WaitingForApproval]);
    let response =
        post_run_events(test, &claimed.holder, &claimed.run, waiting).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    let action = run_command_action(summary);
    ask_for_approval(test, &claimed.holder, &claimed.run, action).await
}

pub async fn ask_while_running(
    test: &TestServer,
    summary: &str,
) -> (ClaimedRun, ApprovalRequest) {
    let claimed = start_claimed_run(test).await;
    let approval = ask_during(test, &claimed, summary).await;
    (claimed, approval)
}

pub async fn list_approvals(
    test: &TestServer,
    device: &DeviceIdentity,
) -> Vec<ApprovalRequest> {
    let response = test.get(device, "/approvals").await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

pub async fn decide_approval(
    test: &TestServer,
    owner: &DeviceIdentity,
    approval: &ApprovalRequest,
    decision: ApprovalDecision,
) -> StatusCode {
    let signed = sign_decision(owner, approval, decision, test.now())
        .expect("the decision signs");
    let request = DecideApprovalRequest { decision: signed };
    let path = format!("/approvals/{}/decision", approval.id.0);
    test.post(owner, &path, &request).await.status
}

pub fn find_listed<'listed>(
    approvals: &'listed [ApprovalRequest],
    approval: &ApprovalRequest,
) -> Option<&'listed ApprovalRequest> {
    approvals.iter().find(|listed| listed.id == approval.id)
}

use axum::http::StatusCode;
use orchestration_api::work::{
    ClaimResponse, CreateApprovalRequest, DecideApprovalRequest, TaskStart,
};
use orchestration_core::approval::{
    ApprovalAction, ApprovalDecision, ApprovalRequest,
};
use orchestration_core::device::{DeviceRole, RunnerTarget};
use orchestration_security::decisions::sign_decision;
use orchestration_security::identity::DeviceIdentity;
use proptest::prelude::*;

use crate::fixtures::{
    Account, create_account, create_project, heartbeat_with,
    identity_from_seed, one_agent_task, pair_device, save_task,
    send_heartbeat,
};
use crate::test_client::{TestServer, block_on};

const RUNNER_SEED: u8 = 60;

fn push_action() -> ApprovalAction {
    ApprovalAction::PushCommits {
        repository: "github.com/acme/app".to_owned(),
        branch: "release".to_owned(),
        commits: vec!["a41f2c0".to_owned(), "9be07d1".to_owned()],
    }
}

async fn request_approval(
    test: &TestServer,
) -> (Account, DeviceIdentity, ApprovalRequest) {
    let account = create_account(test).await;
    let project = create_project(test, &account).await;
    let runner = identity_from_seed(RUNNER_SEED);
    pair_device(test, &account, &runner, "mac-studio", DeviceRole::Runner)
        .await;
    send_heartbeat(test, &runner, &heartbeat_with(&[], 2, 0)).await;
    let task = one_agent_task(project.id, RunnerTarget::AnyFreeRunner, None);
    save_task(test, &account, task, TaskStart::Now).await;
    let claim: ClaimResponse =
        test.post_empty(&runner, "/runners/claim").await.json();
    let run = claim.assignment.expect("the runner gets the run").run;
    let request = CreateApprovalRequest {
        run_id: Some(run.id),
        action: push_action(),
    };
    let response = test.post(&runner, "/approvals", &request).await;
    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    (account, runner, response.json())
}

fn decision_path(approval: &ApprovalRequest) -> String {
    format!("/approvals/{}/decision", approval.id.0)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(12))]

    #[test]
    fn test_decide_approval_property_rejects_signatures_that_do_not_verify(
        signature_bytes in proptest::collection::vec(any::<u8>(), 0..80),
        is_approved in any::<bool>(),
    ) {
        let test = TestServer::start();
        let (status, approvals) = block_on(async {
            let (account, _runner, approval) = request_approval(&test).await;
            let decision = if is_approved {
                ApprovalDecision::Approved
            } else {
                ApprovalDecision::Denied
            };
            let mut signed = sign_decision(
                &account.owner,
                &approval,
                decision,
                test.now(),
            )
            .expect("the decision signs");
            signed.signature = signature_bytes;
            let request = DecideApprovalRequest { decision: signed };
            let response = test
                .post(&account.owner, &decision_path(&approval), &request)
                .await;
            let approvals: Vec<ApprovalRequest> =
                test.get(&account.owner, "/approvals").await.json();
            (response.status, approvals)
        });

        prop_assert_eq!(status, StatusCode::FORBIDDEN);
        prop_assert!(approvals[0].decision.is_none());
    }

    #[test]
    fn test_decide_approval_property_a_decision_is_final(
        first_approves in any::<bool>(),
        second_approves in any::<bool>(),
    ) {
        let test = TestServer::start();
        let (first_status, second_status, approvals) = block_on(async {
            let (account, _runner, approval) = request_approval(&test).await;
            let mut statuses = Vec::new();
            for approves in [first_approves, second_approves] {
                let decision = if approves {
                    ApprovalDecision::Approved
                } else {
                    ApprovalDecision::Denied
                };
                let signed = sign_decision(
                    &account.owner,
                    &approval,
                    decision,
                    test.now(),
                )
                .expect("the decision signs");
                let request = DecideApprovalRequest { decision: signed };
                let response = test
                    .post(&account.owner, &decision_path(&approval), &request)
                    .await;
                statuses.push(response.status);
            }
            let approvals: Vec<ApprovalRequest> =
                test.get(&account.owner, "/approvals").await.json();
            (statuses[0], statuses[1], approvals)
        });

        prop_assert_eq!(first_status, StatusCode::OK);
        prop_assert_eq!(second_status, StatusCode::CONFLICT);
        let stored = approvals[0].decision.as_ref().expect("decided");
        let expected = if first_approves {
            ApprovalDecision::Approved
        } else {
            ApprovalDecision::Denied
        };
        prop_assert_eq!(stored.decision, expected);
    }
}

#[test]
fn clients_cannot_ask_for_approvals_and_runners_cannot_decide() {
    let test = TestServer::start();
    let (client_status, runner_status) = block_on(async {
        let (account, runner, approval) = request_approval(&test).await;
        let request = CreateApprovalRequest {
            run_id: None,
            action: push_action(),
        };
        let client_response =
            test.post(&account.owner, "/approvals", &request).await;
        let decided_at = test.now();
        let signed = sign_decision(
            &runner,
            &approval,
            ApprovalDecision::Approved,
            decided_at,
        )
        .expect("the decision signs");
        let decide_request = DecideApprovalRequest { decision: signed };
        let runner_response = test
            .post(&runner, &decision_path(&approval), &decide_request)
            .await;
        (client_response.status, runner_response.status)
    });

    assert_eq!(client_status, StatusCode::FORBIDDEN);
    assert_eq!(runner_status, StatusCode::FORBIDDEN);
}

use orchestration_api::work::DecideApprovalRequest;
use orchestration_core::approval::{ApprovalDecision, ApprovalRequest};
use orchestration_security::decisions::verify_decision;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::command_builders::{PreparedWorkspace, prepare_workspace};
use crate::support::test_device::{describe, fail};

const APPROVAL_CASES: u32 = 4;
const REPOSITORY: &str = "github.com/acme/app";
const COMMIT_TEXT: &str = "a41f2c0 Use CI signing profile";
const UNKNOWN_APPROVAL_ID: &str = "00000000-0000-0000-0000-000000000042";

fn create_push_approval(
    prepared: &PreparedWorkspace,
    commit_count: usize,
) -> Result<ApprovalRequest, String> {
    let created = prepared.device.run(&json!({
        "command": "create_approval",
        "run_id": null,
        "action": {
            "kind": "push_commits",
            "repository": REPOSITORY,
            "branch": "release",
            "commits": vec![COMMIT_TEXT; commit_count],
        },
    }))?;
    serde_json::from_value(created).map_err(describe)
}

fn read_signing_key(prepared: &PreparedWorkspace) -> Result<Vec<u8>, String> {
    let identity = prepared.device.load_identity()?;
    Ok(identity.public_identity().signing_public_key)
}

fn read_sent_decision(
    prepared: &PreparedWorkspace,
    approval: &ApprovalRequest,
) -> Result<DecideApprovalRequest, String> {
    let decision_path = format!("/approvals/{}/decision", approval.id.0);
    let sent_decision = prepared
        .server
        .recorded_requests()
        .into_iter()
        .find(|request| request.path == decision_path)
        .map(|request| request.body)
        .unwrap_or_default();
    serde_json::from_slice(&sent_decision).map_err(describe)
}

fn choose_decision(is_approved: bool) -> ApprovalDecision {
    if is_approved {
        return ApprovalDecision::Approved;
    }
    ApprovalDecision::Denied
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(APPROVAL_CASES))]

    #[test]
    fn test_decide_approval_property_sends_a_decision_that_verifies(
        commit_count in 1_usize..5,
        is_approved in any::<bool>(),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let approval =
            create_push_approval(&prepared, commit_count).map_err(fail)?;
        let decision = choose_decision(is_approved);

        let approvals = prepared
            .device
            .run(&json!({ "command": "list_approvals" }))
            .map_err(fail)?;
        prepared
            .device
            .run(&json!({
                "command": "decide_approval",
                "approval_id": approval.id,
                "decision": decision,
            }))
            .map_err(fail)?;

        let commit_word = if commit_count == 1 { "commit" } else { "commits" };
        let expected_description =
            format!("Push {commit_count} {commit_word} to {REPOSITORY}");
        prop_assert_eq!(&approvals["waiting_count"], &json!(1));
        prop_assert_eq!(
            &approvals["approvals"][0]["description"],
            &Value::String(expected_description)
        );
        let decision_request =
            read_sent_decision(&prepared, &approval).map_err(fail)?;
        let key = read_signing_key(&prepared).map_err(fail)?;
        prop_assert_eq!(decision_request.decision.decision, decision);
        prop_assert!(
            verify_decision(&approval, &decision_request.decision, &key)
                .is_ok()
        );
    }
}

#[test]
fn deciding_an_unknown_approval_gives_a_defined_error() {
    let Ok(prepared) = prepare_workspace() else {
        panic!("the workspace is prepared");
    };

    let decided = prepared.device.run(&json!({
        "command": "decide_approval",
        "approval_id": UNKNOWN_APPROVAL_ID,
        "decision": "approved",
    }));

    assert!(decided.is_err());
}

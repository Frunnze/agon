use axum::http::StatusCode;
use orchestration_api::catalog::ChangeWorkspaceApprovalPolicyRequest;
use orchestration_api::work::TaskStart;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::identifiers::WorkspaceId;
use orchestration_core::workspace::Workspace;
use proptest::prelude::*;

use crate::claim_fixtures::{claim, pair_runners};
use crate::fixtures::{
    Account, create_account, identity_from_seed, save_task, workspace_task,
};
use crate::test_client::{TestServer, block_on};

const WORKSPACE_APPROVAL_CASES: u32 = 6;
const RUNNER_SLOTS: u32 = 2;
const STRANGER_SEED: u8 = 91;

fn approval_policy() -> impl Strategy<Value = ApprovalPolicy> {
    prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ]
}

fn approval_policy_path(workspace_id: WorkspaceId) -> String {
    format!("/workspaces/{}/approval-policy", workspace_id.0)
}

async fn read_workspace(test: &TestServer, account: &Account) -> Workspace {
    let response = test.get(&account.owner, "/workspaces").await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    let workspaces: Vec<Workspace> = response.json();
    workspaces
        .into_iter()
        .find(|workspace| workspace.id == account.workspace_id)
        .expect("the account's workspace is listed")
}

async fn change_policy(
    test: &TestServer,
    account: &Account,
    approval_policy: ApprovalPolicy,
) -> Workspace {
    let request = ChangeWorkspaceApprovalPolicyRequest { approval_policy };
    let path = approval_policy_path(account.workspace_id);
    let response = test.put(&account.owner, &path, &request).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

#[test]
fn test_create_account_starts_the_workspace_on_auto() {
    let test = TestServer::start();

    let workspace = block_on(async {
        let account = create_account(&test).await;
        read_workspace(&test, &account).await
    });

    assert_eq!(workspace.approval_policy, ApprovalPolicy::NeverAsk);
}

#[test]
fn test_change_workspace_approval_policy_refuses_outsiders() {
    let test = TestServer::start();
    let stranger = identity_from_seed(STRANGER_SEED);

    let status = block_on(async {
        let account = create_account(&test).await;
        let request = ChangeWorkspaceApprovalPolicyRequest {
            approval_policy: ApprovalPolicy::AskBeforeRiskyActions,
        };
        let path = approval_policy_path(account.workspace_id);
        test.put(&stranger, &path, &request).await.status
    });

    assert!(status.is_client_error(), "{status}");
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(WORKSPACE_APPROVAL_CASES))]

    #[test]
    fn test_change_workspace_approval_policy_property_the_choice_is_kept(
        approval_policy in approval_policy(),
    ) {
        let test = TestServer::start();

        let (answered, listed) = block_on(async {
            let account = create_account(&test).await;
            let answered = change_policy(&test, &account, approval_policy)
                .await;
            let listed = read_workspace(&test, &account).await;
            (answered, listed)
        });

        prop_assert_eq!(answered.approval_policy, approval_policy);
        prop_assert_eq!(listed.approval_policy, approval_policy);
    }

    #[test]
    fn test_claim_next_run_property_carries_the_workspace_approval_policy(
        approval_policy in approval_policy(),
    ) {
        let test = TestServer::start();

        let claimed = block_on(async {
            let account = create_account(&test).await;
            let runners = pair_runners(&test, &account, 1, RUNNER_SLOTS).await;
            change_policy(&test, &account, approval_policy).await;
            let task = workspace_task(account.workspace_id);
            save_task(&test, &account, task, TaskStart::Now).await;
            claim(&test, &runners[0]).await.assignment
        });

        let assignment = claimed
            .ok_or_else(|| TestCaseError::fail("the runner got no run"))?;
        prop_assert_eq!(assignment.workspace_approval_policy, approval_policy);
    }
}

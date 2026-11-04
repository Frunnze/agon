use axum::http::StatusCode;
use orchestration_api::catalog::SetProtectedFilesRequest;
use orchestration_api::work::TaskStart;
use orchestration_core::identifiers::WorkspaceId;
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::workspace::Workspace;
use proptest::collection::btree_set;
use proptest::prelude::*;

use crate::claim_fixtures::{claim, pair_runners};
use crate::fixtures::{
    Account, create_account, identity_from_seed, save_task, workspace_task,
};
use crate::test_client::{TestServer, block_on};

const PROTECTED_FILES_CASES: u32 = 6;
const RUNNER_SLOTS: u32 = 2;
const STRANGER_SEED: u8 = 93;

fn protected_files() -> impl Strategy<Value = ProtectedFiles> {
    btree_set("~/\\.[a-z]{1,8}|[a-z]{1,8}\\.pem", 0..6).prop_map(|names| {
        ProtectedFiles {
            patterns: names.into_iter().collect(),
        }
    })
}

fn protected_files_path(workspace_id: WorkspaceId) -> String {
    format!("/workspaces/{}/protected-files", workspace_id.0)
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

async fn set_protected_files(
    test: &TestServer,
    account: &Account,
    protected_files: ProtectedFiles,
) -> Workspace {
    let request = SetProtectedFilesRequest { protected_files };
    let path = protected_files_path(account.workspace_id);
    let response = test.put(&account.owner, &path, &request).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

#[test]
fn test_create_account_starts_the_workspace_with_the_default_list() {
    let test = TestServer::start();

    let workspace = block_on(async {
        let account = create_account(&test).await;
        read_workspace(&test, &account).await
    });

    assert_eq!(workspace.protected_files, ProtectedFiles::default());
}

#[test]
fn test_set_protected_files_refuses_outsiders() {
    let test = TestServer::start();
    let stranger = identity_from_seed(STRANGER_SEED);

    let status = block_on(async {
        let account = create_account(&test).await;
        let request = SetProtectedFilesRequest {
            protected_files: ProtectedFiles {
                patterns: Vec::new(),
            },
        };
        let path = protected_files_path(account.workspace_id);
        test.put(&stranger, &path, &request).await.status
    });

    assert!(status.is_client_error(), "{status}");
}

#[test]
fn test_set_protected_files_refuses_an_invalid_pattern() {
    let test = TestServer::start();

    let (status, listed) = block_on(async {
        let account = create_account(&test).await;
        let request = SetProtectedFilesRequest {
            protected_files: ProtectedFiles {
                patterns: vec!["~/../secret".to_owned()],
            },
        };
        let path = protected_files_path(account.workspace_id);
        let status = test.put(&account.owner, &path, &request).await.status;
        (status, read_workspace(&test, &account).await)
    });

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(listed.protected_files, ProtectedFiles::default());
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROTECTED_FILES_CASES))]

    #[test]
    fn test_set_protected_files_property_the_list_is_kept(
        protected in protected_files(),
    ) {
        let test = TestServer::start();

        let (answered, listed) = block_on(async {
            let account = create_account(&test).await;
            let answered =
                set_protected_files(&test, &account, protected.clone()).await;
            let listed = read_workspace(&test, &account).await;
            (answered, listed)
        });

        prop_assert_eq!(&answered.protected_files, &protected);
        prop_assert_eq!(&listed.protected_files, &protected);
    }

    #[test]
    fn test_claim_next_run_property_carries_the_protected_files(
        protected in protected_files(),
    ) {
        let test = TestServer::start();

        let claimed = block_on(async {
            let account = create_account(&test).await;
            let runners = pair_runners(&test, &account, 1, RUNNER_SLOTS).await;
            set_protected_files(&test, &account, protected.clone()).await;
            let task = workspace_task(account.workspace_id);
            save_task(&test, &account, task, TaskStart::Now).await;
            claim(&test, &runners[0]).await.assignment
        });

        let assignment = claimed
            .ok_or_else(|| TestCaseError::fail("the runner got no run"))?;
        prop_assert_eq!(assignment.protected_files, protected);
    }
}

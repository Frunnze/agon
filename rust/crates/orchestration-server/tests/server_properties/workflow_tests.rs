use axum::http::StatusCode;
use orchestration_api::catalog::{SaveWorkflowRequest, SignWorkflowRequest};
use orchestration_api::work::TaskStart;
use orchestration_core::device::RunnerTarget;
use orchestration_core::workflow::{
    AgentConnection, SignatureState, Workflow,
};
use orchestration_core::workflow_document::render_workflow_document;
use orchestration_security::documents::{sign_document, signature_state};
use orchestration_security::identity::DeviceIdentity;
use proptest::prelude::*;

use crate::fixtures::{Account, create_account, create_project, save_task};
use crate::test_client::{TestServer, block_on};
use crate::workflow_fixtures::{
    create_workflow, release_workflow, workflow_agent, workflow_task,
};

fn sample_workflow() -> Workflow {
    release_workflow(
        workflow_agent("plan", RunnerTarget::AnyFreeRunner),
        workflow_agent("build-ios", RunnerTarget::AnyFreeRunner),
    )
}

fn workflow_path(workflow: &Workflow) -> String {
    format!("/workflows/{}", workflow.id.0)
}

async fn sign_workflow(
    test: &TestServer,
    account: &Account,
    workflow: &Workflow,
) -> Workflow {
    let document = render_workflow_document(workflow);
    let request = SignWorkflowRequest {
        signature: sign_document(&account.owner, &document),
    };
    let path = format!("{}/signature", workflow_path(workflow));
    let response = test.post(&account.owner, &path, &request).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

fn state_of(workflow: &Workflow, signer: &DeviceIdentity) -> SignatureState {
    let signer_key = signer.public_identity().signing_public_key;
    signature_state(
        workflow.signature.as_ref(),
        &render_workflow_document(workflow),
        Some(&signer_key),
    )
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(16))]

    #[test]
    fn test_update_workflow_property_changes_keep_the_old_signature(
        new_name in "[a-z][a-z0-9-]{0,20}",
    ) {
        prop_assume!(new_name != "plan" && new_name != "build-ios");
        let test = TestServer::start();
        let (owner, signed, changed) = block_on(async {
            let account = create_account(&test).await;
            let created =
                create_workflow(&test, &account, sample_workflow()).await;
            let signed = sign_workflow(&test, &account, &created).await;
            let mut edited = signed.clone();
            edited.agents[0].name = new_name;
            edited.signature = None;
            let request = SaveWorkflowRequest { workflow: edited };
            let response = test
                .put(&account.owner, &workflow_path(&signed), &request)
                .await;
            assert_eq!(response.status, StatusCode::OK, "{response:?}");
            let changed: Workflow = response.json();
            (account.owner, signed, changed)
        });

        prop_assert_eq!(state_of(&signed, &owner), SignatureState::Signed);
        prop_assert_eq!(&changed.signature, &signed.signature);
        prop_assert_eq!(
            state_of(&changed, &owner),
            SignatureState::ChangedNotSigned
        );
    }

    #[test]
    fn test_sign_workflow_property_rejects_signatures_of_other_documents(
        extra_text in "\\PC{1,40}",
    ) {
        let test = TestServer::start();
        let status = block_on(async {
            let account = create_account(&test).await;
            let created =
                create_workflow(&test, &account, sample_workflow()).await;
            let document =
                format!("{}{extra_text}", render_workflow_document(&created));
            let request = SignWorkflowRequest {
                signature: sign_document(&account.owner, &document),
            };
            let path = format!("{}/signature", workflow_path(&created));
            test.post(&account.owner, &path, &request).await.status
        });

        prop_assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    }
}

#[test]
fn discard_restores_the_last_signed_version() {
    let test = TestServer::start();
    let (owner, signed, restored) = block_on(async {
        let account = create_account(&test).await;
        let created =
            create_workflow(&test, &account, sample_workflow()).await;
        let signed = sign_workflow(&test, &account, &created).await;
        let mut edited = signed.clone();
        edited.agents[1].name = "train".to_owned();
        let request = SaveWorkflowRequest { workflow: edited };
        let response = test
            .put(&account.owner, &workflow_path(&signed), &request)
            .await;
        assert_eq!(response.status, StatusCode::OK);
        let discard_path = format!("{}/discard", workflow_path(&signed));
        let restored: Workflow =
            test.post_empty(&account.owner, &discard_path).await.json();
        (account.owner, signed, restored)
    });

    assert_eq!(restored, signed);
    assert_eq!(state_of(&restored, &owner), SignatureState::Signed);
}

#[test]
fn discard_without_a_signed_version_is_refused() {
    let test = TestServer::start();
    let status = block_on(async {
        let account = create_account(&test).await;
        let created =
            create_workflow(&test, &account, sample_workflow()).await;
        let discard_path = format!("{}/discard", workflow_path(&created));
        test.post_empty(&account.owner, &discard_path).await.status
    });

    assert_eq!(status, StatusCode::CONFLICT);
}

#[test]
fn workflows_with_cycles_are_rejected() {
    let test = TestServer::start();
    let status = block_on(async {
        let account = create_account(&test).await;
        let mut workflow = sample_workflow();
        let backwards = AgentConnection {
            from: workflow.agents[1].id,
            to: workflow.agents[0].id,
        };
        workflow.connections.push(backwards);
        let request = SaveWorkflowRequest { workflow };
        test.post(&account.owner, "/workflows", &request)
            .await
            .status
    });

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
}

#[test]
fn only_signed_workflows_start() {
    let test = TestServer::start();
    let (unsigned_status, signed_status) = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let created =
            create_workflow(&test, &account, sample_workflow()).await;
        let task = workflow_task(project.id, created.id);
        let saved = save_task(&test, &account, task, TaskStart::Later).await;
        let runs_path = format!("/tasks/{}/runs", saved.task.id.0);
        let unsigned = test.post_empty(&account.owner, &runs_path).await;
        sign_workflow(&test, &account, &created).await;
        let signed = test.post_empty(&account.owner, &runs_path).await;
        (unsigned.status, signed.status)
    });

    assert_eq!(unsigned_status, StatusCode::CONFLICT);
    assert_eq!(signed_status, StatusCode::CREATED);
}

use std::fs;

use axum::http::StatusCode;
use orchestration_api::catalog::SaveWorkflowRequest;
use orchestration_api::updates::AuditView;
use orchestration_core::device::{DeviceRole, RunnerTarget};
use proptest::prelude::*;

use crate::fixtures::{
    create_account, create_project, identity_from_seed, pair_device,
};
use crate::operations::{
    SETUP_CHANGE_COUNT, count_changes, operation_strategy, perform_operation,
};
use crate::test_client::{TestServer, block_on};
use crate::workflow_fixtures::{
    create_workflow, release_workflow, workflow_agent,
};

const STATE_FILE_NAME: &str = "state.json";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(16))]

    #[test]
    fn test_audit_log_property_chain_stays_intact_after_any_operations(
        operations in proptest::collection::vec(operation_strategy(), 0..10),
    ) {
        let test = TestServer::start();
        let audit_view: AuditView = block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            for operation in &operations {
                let status =
                    perform_operation(&test, &account, &project, *operation)
                        .await;
                assert!(status.is_success(), "{operation:?} gave {status}");
            }
            test.get(&account.owner, "/audit").await.json()
        });

        let expected_count = SETUP_CHANGE_COUNT + count_changes(&operations);
        prop_assert!(audit_view.intact);
        prop_assert_eq!(audit_view.entries.len(), expected_count);
        prop_assert_eq!(
            usize::try_from(audit_view.entry_count).expect("count fits"),
            expected_count
        );
        for (position, entry) in audit_view.entries.iter().enumerate() {
            prop_assert_eq!(
                usize::try_from(entry.index).expect("index fits"),
                position
            );
        }
        for pair in audit_view.entries.windows(2) {
            prop_assert_eq!(&pair[1].previous_hash, &pair[0].hash);
        }
        let head_hash = audit_view.entries.last().map(|entry| &entry.hash);
        prop_assert_eq!(head_hash, Some(&audit_view.head_hash));
    }
}

#[test]
fn audit_entries_name_the_acting_device_and_event() {
    let test = TestServer::start();
    let (audit_view, owner_id, runner_id) = block_on(async {
        let account = create_account(&test).await;
        let runner = identity_from_seed(70);
        pair_device(&test, &account, &runner, "gpu-box", DeviceRole::Runner)
            .await;
        let workflow = release_workflow(
            workflow_agent("plan", RunnerTarget::AnyFreeRunner),
            workflow_agent("train", RunnerTarget::AnyFreeRunner),
        );
        let created = create_workflow(&test, &account, workflow).await;
        let path = format!("/workflows/{}", created.id.0);
        let request = SaveWorkflowRequest { workflow: created };
        let changed = test.put(&account.owner, &path, &request).await;
        assert_eq!(changed.status, StatusCode::OK);
        let audit_view: AuditView =
            test.get(&account.owner, "/audit").await.json();
        (audit_view, account.owner.device_id(), runner.device_id())
    });

    let events: Vec<(&str, &str)> = audit_view
        .entries
        .iter()
        .map(|entry| (entry.device_id.0.as_str(), entry.event.as_str()))
        .collect();
    assert_eq!(
        events,
        [
            (
                owner_id.0.as_str(),
                "Created the account with workspace acme"
            ),
            (owner_id.0.as_str(), "Started pairing"),
            (runner_id.0.as_str(), "gpu-box asked to join"),
            (owner_id.0.as_str(), "Paired gpu-box as a runner"),
            (owner_id.0.as_str(), "Created workflow release"),
            (owner_id.0.as_str(), "Changed workflow release"),
        ]
    );
}

#[test]
fn tampering_with_the_saved_log_is_detected() {
    let test = TestServer::start();
    let owner = block_on(async {
        let account = create_account(&test).await;
        create_project(&test, &account).await;
        account.owner
    });
    let state_path = test.directory.path().join(STATE_FILE_NAME);
    let saved_text = fs::read_to_string(&state_path).expect("state is saved");
    let tampered_text = saved_text.replace(
        "Created the account with workspace acme",
        "Created the account with workspace evil",
    );
    assert_ne!(saved_text, tampered_text);
    fs::write(&state_path, tampered_text).expect("state is writable");

    let restarted = test.restart();
    let audit_view: AuditView =
        block_on(restarted.get(&owner, "/audit")).json();

    assert!(!audit_view.intact);
}

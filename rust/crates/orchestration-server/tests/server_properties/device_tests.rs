use axum::http::StatusCode;
use orchestration_api::accounts::{
    AccountView, RevokeDeviceRequest, revocation_statement,
};
use orchestration_api::catalog::{
    AddWorkspaceDeviceRequest, CreateWorkspaceRequest,
};
use orchestration_core::device::{Device, DeviceRole};
use orchestration_core::identifiers::WorkspaceId;
use orchestration_core::workspace::Workspace;
use proptest::prelude::*;
use uuid::Uuid;

use crate::fixtures::{
    SEALED_KEY_BYTES, create_account, identity_from_seed, pair_device,
};
use crate::test_client::{TestServer, block_on};

const SECOND_SEED: u8 = 5;

fn revoke_path(device: &Device) -> String {
    format!("/devices/{}/revoke", device.id.0)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(16))]

    #[test]
    fn test_revoke_device_property_needs_a_signature_that_verifies(
        signature_bytes in proptest::collection::vec(any::<u8>(), 0..80),
    ) {
        let test = TestServer::start();
        let (status, devices) = block_on(async {
            let account = create_account(&test).await;
            let second = identity_from_seed(SECOND_SEED);
            let device = pair_device(
                &test,
                &account,
                &second,
                "mac-studio",
                DeviceRole::Runner,
            )
            .await;
            let request = RevokeDeviceRequest {
                approval_signature: signature_bytes,
            };
            let path = revoke_path(&device);
            let response = test.post(&account.owner, &path, &request).await;
            let devices: Vec<Device> =
                test.get(&account.owner, "/devices").await.json();
            (response.status, devices)
        });

        prop_assert_eq!(status, StatusCode::FORBIDDEN);
        prop_assert!(devices.iter().all(|device| !device.revoked));
    }

    #[test]
    fn test_create_workspace_property_rejects_invalid_names(
        name in "[A-Z ]{1,10}[a-z]{0,5}",
    ) {
        let test = TestServer::start();
        let status = block_on(async {
            let account = create_account(&test).await;
            let request = CreateWorkspaceRequest {
                workspace_id: WorkspaceId(Uuid::new_v4()),
                name,
                sealed_workspace_key: SEALED_KEY_BYTES.to_vec(),
            };
            test.post(&account.owner, "/workspaces", &request).await.status
        });

        prop_assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    }
}

#[test]
fn a_device_cannot_revoke_itself() {
    let test = TestServer::start();
    let status = block_on(async {
        let account = create_account(&test).await;
        let devices: Vec<Device> =
            test.get(&account.owner, "/devices").await.json();
        let own_device = &devices[0];
        let request = RevokeDeviceRequest {
            approval_signature: account
                .owner
                .sign(&revocation_statement(&own_device.id)),
        };
        test.post(&account.owner, &revoke_path(own_device), &request)
            .await
            .status
    });

    assert_eq!(status, StatusCode::FORBIDDEN);
}

#[test]
fn revoking_marks_the_device_everywhere() {
    let test = TestServer::start();
    let devices = block_on(async {
        let account = create_account(&test).await;
        let second = identity_from_seed(SECOND_SEED);
        let device = pair_device(
            &test,
            &account,
            &second,
            "old-macbook",
            DeviceRole::ClientAndRunner,
        )
        .await;
        let request = RevokeDeviceRequest {
            approval_signature: account
                .owner
                .sign(&revocation_statement(&device.id)),
        };
        let response = test
            .post(&account.owner, &revoke_path(&device), &request)
            .await;
        assert_eq!(response.status, StatusCode::OK);
        let repeated = test
            .post(&account.owner, &revoke_path(&device), &request)
            .await;
        assert_eq!(repeated.status, StatusCode::CONFLICT);
        let devices: Vec<Device> =
            test.get(&account.owner, "/devices").await.json();
        devices
    });

    let revoked_device = devices
        .iter()
        .find(|device| device.name == "old-macbook")
        .expect("the device is still listed");
    assert!(revoked_device.revoked);
}

#[test]
fn workspace_membership_can_be_added_and_removed() {
    let test = TestServer::start();
    let (after_adding, after_removing) = block_on(async {
        let account = create_account(&test).await;
        let second = identity_from_seed(SECOND_SEED);
        let device = pair_device(
            &test,
            &account,
            &second,
            "gpu-box",
            DeviceRole::Runner,
        )
        .await;
        let personal_id = WorkspaceId(Uuid::new_v4());
        let create_request = CreateWorkspaceRequest {
            workspace_id: personal_id,
            name: "personal".to_owned(),
            sealed_workspace_key: SEALED_KEY_BYTES.to_vec(),
        };
        let created = test
            .post(&account.owner, "/workspaces", &create_request)
            .await;
        assert_eq!(created.status, StatusCode::CREATED);
        let _workspace: Workspace = created.json();
        let members_path = format!("/workspaces/{}/devices", personal_id.0);
        let add_request = AddWorkspaceDeviceRequest {
            device_id: device.id.clone(),
            sealed_workspace_key: SEALED_KEY_BYTES.to_vec(),
        };
        let added =
            test.post(&account.owner, &members_path, &add_request).await;
        assert_eq!(added.status, StatusCode::OK, "{added:?}");
        let after_adding: AccountView =
            test.get(&second, "/accounts").await.json();
        let member_path = format!("{members_path}/{}", device.id.0);
        let removed = test.delete(&account.owner, &member_path).await;
        assert_eq!(removed.status, StatusCode::NO_CONTENT);
        let after_removing: AccountView =
            test.get(&second, "/accounts").await.json();
        (after_adding, after_removing)
    });

    assert_eq!(after_adding.workspaces.len(), 2);
    assert_eq!(after_adding.sealed_workspace_keys.len(), 2);
    assert_eq!(after_removing.workspaces.len(), 1);
    assert_eq!(after_removing.sealed_workspace_keys.len(), 1);
}

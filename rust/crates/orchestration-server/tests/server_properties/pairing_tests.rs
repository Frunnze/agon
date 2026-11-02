use axum::http::StatusCode;
use chrono::TimeDelta;
use orchestration_api::accounts::{JoinStatus, PairingRequestView};
use orchestration_core::device::DeviceRole;
use orchestration_security::pairing::{
    PAIRING_SESSION_LIFETIME, PairingPublicKeys,
};
use proptest::prelude::*;

use crate::fixtures::{create_account, identity_from_seed, registration_for};
use crate::pairing_fixtures::{
    APPROVER_NONCE, JOINER_NONCE, approval_for, approve_path, approve_session,
    commitment_for, join_session, read_join_status, reveal_approver_nonce,
    send_join, start_pairing,
};
use crate::test_client::{TestServer, block_on};

const JOINING_SEED: u8 = 4;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(16))]

    #[test]
    fn test_approve_pairing_property_works_only_once(
        extra_attempts in 1_usize..4,
    ) {
        let test = TestServer::start();
        let statuses = block_on(async {
            let account = create_account(&test).await;
            let session = start_pairing(&test, &account).await;
            let joining = identity_from_seed(JOINING_SEED);
            let registration =
                registration_for(&joining, "mac-mini", DeviceRole::Runner);
            join_session(&test, &session.code, registration.clone()).await;
            reveal_approver_nonce(
                &test,
                &account,
                &session.code,
                &APPROVER_NONCE,
            )
            .await;
            let approval =
                approval_for(&account, &session.code, &registration);
            let path = approve_path(&session.code);
            let mut statuses = Vec::new();
            for _attempt in 0..=extra_attempts {
                let response =
                    test.post(&account.owner, &path, &approval).await;
                statuses.push(response.status);
            }
            statuses
        });

        prop_assert_eq!(statuses[0], StatusCode::OK);
        for later_status in &statuses[1..] {
            prop_assert_eq!(*later_status, StatusCode::NOT_FOUND);
        }
    }

    #[test]
    fn test_approve_pairing_property_never_works_after_expiry(
        extra_seconds in 0_i64..10_000,
    ) {
        let test = TestServer::start();
        let (approve_status, join_status) = block_on(async {
            let account = create_account(&test).await;
            let session = start_pairing(&test, &account).await;
            let joining = identity_from_seed(JOINING_SEED);
            let registration =
                registration_for(&joining, "mac-mini", DeviceRole::Runner);
            let accepted =
                join_session(&test, &session.code, registration.clone()).await;
            test.clock.advance(
                PAIRING_SESSION_LIFETIME + TimeDelta::seconds(extra_seconds),
            );
            let approval =
                approval_for(&account, &session.code, &registration);
            let path = approve_path(&session.code);
            let response = test.post(&account.owner, &path, &approval).await;
            let join_status =
                read_join_status(&test, accepted.join_id).await;
            (response.status, join_status)
        });

        prop_assert_eq!(approve_status, StatusCode::CONFLICT);
        prop_assert_eq!(join_status, JoinStatus::Expired);
    }

    #[test]
    fn test_join_pairing_property_never_works_after_expiry(
        extra_seconds in 0_i64..10_000,
    ) {
        let test = TestServer::start();
        let status = block_on(async {
            let account = create_account(&test).await;
            let session = start_pairing(&test, &account).await;
            test.clock.advance(
                PAIRING_SESSION_LIFETIME + TimeDelta::seconds(extra_seconds),
            );
            let joining = identity_from_seed(JOINING_SEED);
            let registration =
                registration_for(&joining, "mac-mini", DeviceRole::Runner);
            send_join(&test, &session.code, registration).await.status
        });

        prop_assert_eq!(status, StatusCode::CONFLICT);
    }

    #[test]
    fn test_join_pairing_property_offers_the_approver_keys_and_commitment(
        joining_seed in 10_u8..=255,
    ) {
        let test = TestServer::start();
        let joining = identity_from_seed(joining_seed);
        let (accepted, account, code) = block_on(async {
            let account = create_account(&test).await;
            let session = start_pairing(&test, &account).await;
            let registration =
                registration_for(&joining, "mac-mini", DeviceRole::Runner);
            let accepted =
                join_session(&test, &session.code, registration).await;
            (accepted, account, session.code)
        });
        let approver = PairingPublicKeys::of_identity(&account.owner);
        let expected_commitment =
            commitment_for(&account, &code, &APPROVER_NONCE).commitment;

        prop_assert_eq!(
            accepted.approver_signing_public_key,
            approver.signing_public_key
        );
        prop_assert_eq!(
            accepted.approver_sealing_public_key,
            approver.sealing_public_key
        );
        prop_assert_eq!(accepted.approver_commitment, expected_commitment);
    }
}

#[test]
fn pairing_codes_are_shown_in_two_groups_of_three() {
    let test = TestServer::start();
    let session = block_on(async {
        let account = create_account(&test).await;
        start_pairing(&test, &account).await
    });
    let groups: Vec<&str> = session.code.split('-').collect();

    assert_eq!(groups.len(), 2);
    assert!(groups.iter().all(|group| group.len() == 3));
    assert_eq!(session.expires_at, test.now() + PAIRING_SESSION_LIFETIME);
}

#[test]
fn joining_device_waits_then_receives_its_account() {
    let test = TestServer::start();
    let (waiting, view, approved) = block_on(async {
        let account = create_account(&test).await;
        let session = start_pairing(&test, &account).await;
        let joining = identity_from_seed(JOINING_SEED);
        let registration =
            registration_for(&joining, "mac-mini", DeviceRole::Runner);
        let typed_code = session.code.replace('-', " ").to_lowercase();
        let accepted =
            join_session(&test, &typed_code, registration.clone()).await;
        let waiting = read_join_status(&test, accepted.join_id).await;
        let view_path = format!("/pairing/sessions/{}", session.code);
        let view: PairingRequestView =
            test.get(&account.owner, &view_path).await.json();
        let approve_response =
            approve_session(&test, &account, &session.code, &registration)
                .await;
        assert_eq!(approve_response.status, StatusCode::OK);
        let approved = read_join_status(&test, accepted.join_id).await;
        (waiting, view, approved)
    });

    assert_eq!(
        waiting,
        JoinStatus::Waiting {
            approver_nonce: None
        }
    );
    let joining_device = view.joining.expect("the join is visible");
    assert_eq!(joining_device.name, "mac-mini");
    assert_eq!(joining_device.joiner_nonce, Some(JOINER_NONCE.to_vec()));
    assert_eq!(joining_device.approver_nonce, None);
    let JoinStatus::Approved {
        account,
        approver_nonce,
    } = approved
    else {
        panic!("the join is approved, not {approved:?}");
    };
    assert_eq!(approver_nonce, APPROVER_NONCE.to_vec());
    assert_eq!(account.device.name, "mac-mini");
    assert_eq!(account.workspaces.len(), 1);
    assert_eq!(account.sealed_workspace_keys.len(), 1);
}

#[test]
fn rejected_joins_report_rejection() {
    let test = TestServer::start();
    let status = block_on(async {
        let account = create_account(&test).await;
        let session = start_pairing(&test, &account).await;
        let joining = identity_from_seed(JOINING_SEED);
        let registration =
            registration_for(&joining, "mac-mini", DeviceRole::Runner);
        let accepted = join_session(&test, &session.code, registration).await;
        let reject_path = format!("/pairing/sessions/{}/reject", session.code);
        let reject_response =
            test.post_empty(&account.owner, &reject_path).await;
        assert_eq!(reject_response.status, StatusCode::NO_CONTENT);
        read_join_status(&test, accepted.join_id).await
    });

    assert_eq!(status, JoinStatus::Rejected);
}

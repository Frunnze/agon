use axum::http::StatusCode;
use orchestration_core::device::DeviceRole;

use crate::fixtures::{create_account, identity_from_seed, registration_for};
use crate::pairing_exchange_tests::waiting_with;
use crate::pairing_fixtures::{
    APPROVER_NONCE, approval_for, approve_path, join_session, open_session,
    read_join_status, reveal_approver_nonce, send_join, start_pairing,
};
use crate::test_client::{TestServer, block_on};

const JOINING_SEED: u8 = 4;
const JOINING_NAME: &str = "mac-mini";

#[test]
fn joining_a_code_without_a_commitment_is_refused() {
    let test = TestServer::start();
    let status = block_on(async {
        let account = create_account(&test).await;
        let session = open_session(&test, &account).await;
        let joining = identity_from_seed(JOINING_SEED);
        let registration =
            registration_for(&joining, JOINING_NAME, DeviceRole::Runner);
        send_join(&test, &session.code, registration).await.status
    });

    assert_eq!(status, StatusCode::CONFLICT);
}

#[test]
fn the_approver_reveals_only_after_the_joiner_nonce() {
    let test = TestServer::start();
    let (early_status, approve_status) = block_on(async {
        let account = create_account(&test).await;
        let session = start_pairing(&test, &account).await;
        let joining = identity_from_seed(JOINING_SEED);
        let registration =
            registration_for(&joining, JOINING_NAME, DeviceRole::Runner);
        send_join(&test, &session.code, registration.clone()).await;
        let early = reveal_approver_nonce(
            &test,
            &account,
            &session.code,
            &APPROVER_NONCE,
        )
        .await;
        let approval = approval_for(&account, &session.code, &registration);
        let approved = test
            .post(&account.owner, &approve_path(&session.code), &approval)
            .await;
        (early.status, approved.status)
    });

    assert_eq!(early_status, StatusCode::CONFLICT);
    assert_eq!(approve_status, StatusCode::CONFLICT);
}

#[test]
fn an_approval_from_an_earlier_attempt_is_refused() {
    let test = TestServer::start();
    let status = block_on(async {
        let account = create_account(&test).await;
        let joining = identity_from_seed(JOINING_SEED);
        let registration =
            registration_for(&joining, JOINING_NAME, DeviceRole::Runner);
        let earlier = start_pairing(&test, &account).await;
        let old_approval =
            approval_for(&account, &earlier.code, &registration);
        let session = start_pairing(&test, &account).await;
        join_session(&test, &session.code, registration).await;
        reveal_approver_nonce(&test, &account, &session.code, &APPROVER_NONCE)
            .await;
        test.post(&account.owner, &approve_path(&session.code), &old_approval)
            .await
            .status
    });

    assert_eq!(status, StatusCode::CONFLICT);
}

#[test]
fn the_join_status_relays_the_revealed_approver_nonce() {
    let test = TestServer::start();
    let (before, after) = block_on(async {
        let account = create_account(&test).await;
        let session = start_pairing(&test, &account).await;
        let joining = identity_from_seed(JOINING_SEED);
        let registration =
            registration_for(&joining, JOINING_NAME, DeviceRole::Runner);
        let accepted = join_session(&test, &session.code, registration).await;
        let before = read_join_status(&test, accepted.join_id).await;
        reveal_approver_nonce(&test, &account, &session.code, &APPROVER_NONCE)
            .await;
        let after = read_join_status(&test, accepted.join_id).await;
        (before, after)
    });

    assert_eq!(before, waiting_with(None));
    assert_eq!(after, waiting_with(Some(APPROVER_NONCE.to_vec())));
}

use axum::http::StatusCode;
use orchestration_api::accounts::{
    ApprovePairingRequest, JoinStatus, PairingCommitment,
};
use orchestration_core::device::{Device, DeviceRole};
use orchestration_security::pairing::{
    PAIRING_COMMITMENT_LENGTH, PAIRING_NONCE_LENGTH, PairingCode,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::fixtures::{
    Account, create_account, identity_from_seed, registration_for,
};
use crate::pairing_fixtures::{
    APPROVER_NONCE, JOINER_NONCE, approval_for, approval_signed_over,
    approve_path, commitment_for, commitment_path, join_session, open_session,
    read_join_status, reveal_approver_nonce, send_join, send_joiner_nonce,
    start_pairing, transcript_for,
};
use crate::test_client::{TestServer, block_on};

const EXCHANGE_CASES: u32 = 12;
const JOINING_SEED: u8 = 4;
const JOINING_NAME: &str = "mac-mini";
const TRANSCRIPT_PART_COUNT: usize = 4;
const LONGEST_FUZZ_SIGNATURE: usize = 96;
const OTHER_CODE: &str = "000000";

async fn list_devices(test: &TestServer, account: &Account) -> Vec<Device> {
    test.get(&account.owner, "/devices").await.json()
}

pub fn waiting_with(approver_nonce: Option<Vec<u8>>) -> JoinStatus {
    JoinStatus::Waiting { approver_nonce }
}

fn tampered_approval(
    account: &Account,
    code: &str,
    part: usize,
    replacement_byte: u8,
) -> ApprovePairingRequest {
    let joining = identity_from_seed(JOINING_SEED);
    let registration =
        registration_for(&joining, JOINING_NAME, DeviceRole::Runner);
    let mut transcript = transcript_for(account, code, &registration);
    match part {
        0 => transcript.joiner_nonce[0] ^= replacement_byte | 1,
        1 => transcript.approver_nonce[0] ^= replacement_byte | 1,
        2 => {
            let substitute = identity_from_seed(replacement_byte | 1);
            transcript.joiner.signing_public_key =
                substitute.public_identity().signing_public_key;
        }
        _ => {
            transcript.code = PairingCode::parse(OTHER_CODE)
                .expect("the other code is canonical");
        }
    }
    approval_signed_over(account, &transcript)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(EXCHANGE_CASES))]

    #[test]
    fn test_commit_pairing_property_takes_one_commitment_of_its_length(
        commitment_length in 0_usize..=(2 * PAIRING_COMMITMENT_LENGTH),
    ) {
        let test = TestServer::start();
        let (first_status, second_status) = block_on(async {
            let account = create_account(&test).await;
            let session = open_session(&test, &account).await;
            let path = commitment_path(&session.code);
            let first = PairingCommitment {
                commitment: vec![APPROVER_NONCE[0]; commitment_length],
            };
            let first_response = test.post(&account.owner, &path, &first).await;
            let second =
                commitment_for(&account, &session.code, &APPROVER_NONCE);
            let second_response =
                test.post(&account.owner, &path, &second).await;
            (first_response.status, second_response.status)
        });

        if commitment_length == PAIRING_COMMITMENT_LENGTH {
            prop_assert_eq!(first_status, StatusCode::NO_CONTENT);
            prop_assert_eq!(second_status, StatusCode::CONFLICT);
        } else {
            prop_assert_eq!(first_status, StatusCode::UNPROCESSABLE_ENTITY);
            prop_assert_eq!(second_status, StatusCode::NO_CONTENT);
        }
    }

    #[test]
    fn test_approve_pairing_property_refuses_a_mismatched_transcript(
        part in 0..TRANSCRIPT_PART_COUNT,
        replacement_byte in 2_u8..=255,
    ) {
        let test = TestServer::start();
        let (status, device_count, join_status) = block_on(async {
            let account = create_account(&test).await;
            let session = start_pairing(&test, &account).await;
            let joining = identity_from_seed(JOINING_SEED);
            let registration =
                registration_for(&joining, JOINING_NAME, DeviceRole::Runner);
            let accepted =
                join_session(&test, &session.code, registration).await;
            reveal_approver_nonce(
                &test,
                &account,
                &session.code,
                &APPROVER_NONCE,
            )
            .await;
            let approval = tampered_approval(
                &account,
                &session.code,
                part,
                replacement_byte,
            );
            let response = test
                .post(&account.owner, &approve_path(&session.code), &approval)
                .await;
            let devices = list_devices(&test, &account).await;
            let join_status = read_join_status(&test, accepted.join_id).await;
            (response.status, devices.len(), join_status)
        });

        prop_assert_eq!(status, StatusCode::CONFLICT);
        prop_assert_eq!(device_count, 1);
        prop_assert_eq!(
            join_status,
            waiting_with(Some(APPROVER_NONCE.to_vec()))
        );
    }

    #[test]
    fn test_approve_pairing_property_refuses_a_fuzzed_signature(
        fuzzed_signature in vec(any::<u8>(), 0..LONGEST_FUZZ_SIGNATURE),
    ) {
        let test = TestServer::start();
        let status = block_on(async {
            let account = create_account(&test).await;
            let session = start_pairing(&test, &account).await;
            let joining = identity_from_seed(JOINING_SEED);
            let registration =
                registration_for(&joining, JOINING_NAME, DeviceRole::Runner);
            join_session(&test, &session.code, registration.clone()).await;
            reveal_approver_nonce(
                &test,
                &account,
                &session.code,
                &APPROVER_NONCE,
            )
            .await;
            let mut approval =
                approval_for(&account, &session.code, &registration);
            approval.approval_signature = fuzzed_signature;
            test.post(&account.owner, &approve_path(&session.code), &approval)
                .await
                .status
        });

        prop_assert_eq!(status, StatusCode::CONFLICT);
    }

    #[test]
    fn test_reveal_approver_nonce_property_refuses_a_replayed_nonce(
        replayed_nonce in vec(any::<u8>(), PAIRING_NONCE_LENGTH),
    ) {
        prop_assume!(replayed_nonce != APPROVER_NONCE.to_vec());
        let test = TestServer::start();
        let (status, join_status) = block_on(async {
            let account = create_account(&test).await;
            let session = start_pairing(&test, &account).await;
            let joining = identity_from_seed(JOINING_SEED);
            let registration =
                registration_for(&joining, JOINING_NAME, DeviceRole::Runner);
            let accepted =
                join_session(&test, &session.code, registration).await;
            let revealed = reveal_approver_nonce(
                &test,
                &account,
                &session.code,
                &replayed_nonce,
            )
            .await;
            let join_status = read_join_status(&test, accepted.join_id).await;
            (revealed.status, join_status)
        });

        prop_assert_eq!(status, StatusCode::CONFLICT);
        prop_assert_eq!(join_status, waiting_with(None));
    }

    #[test]
    fn test_send_joiner_nonce_property_takes_one_nonce_of_nonce_length(
        nonce_length in 0_usize..=(2 * PAIRING_NONCE_LENGTH),
    ) {
        let test = TestServer::start();
        let (first_status, second_status) = block_on(async {
            let account = create_account(&test).await;
            let session = start_pairing(&test, &account).await;
            let joining = identity_from_seed(JOINING_SEED);
            let registration =
                registration_for(&joining, JOINING_NAME, DeviceRole::Runner);
            let joined = send_join(&test, &session.code, registration).await;
            let join_id = joined.json::<
                orchestration_api::accounts::JoinAccepted,
            >()
            .join_id;
            let nonce = vec![JOINER_NONCE[0]; nonce_length];
            let first = send_joiner_nonce(&test, join_id, &nonce).await;
            let second =
                send_joiner_nonce(&test, join_id, &JOINER_NONCE).await;
            (first.status, second.status)
        });

        if nonce_length == PAIRING_NONCE_LENGTH {
            prop_assert_eq!(first_status, StatusCode::NO_CONTENT);
            prop_assert_eq!(second_status, StatusCode::CONFLICT);
        } else {
            prop_assert_eq!(first_status, StatusCode::UNPROCESSABLE_ENTITY);
            prop_assert_eq!(second_status, StatusCode::NO_CONTENT);
        }
    }
}

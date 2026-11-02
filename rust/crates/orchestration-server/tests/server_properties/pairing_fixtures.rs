use axum::http::{Method, StatusCode};
use orchestration_api::accounts::{
    ApprovePairingRequest, DeviceRegistration, JoinAccepted, JoinRequest,
    JoinStatus, PairingCommitment, PairingNonce, PairingSessionCreated,
    SealedWorkspaceKey,
};
use orchestration_api::routes::{PAIRING_JOIN, PAIRING_SESSIONS};
use orchestration_security::pairing::{
    PAIRING_NONCE_LENGTH, PairingCode, PairingPublicKeys, PairingTranscript,
    commit_to_approver_nonce,
};
use uuid::Uuid;

use crate::fixtures::{Account, SEALED_KEY_BYTES};
use crate::test_client::{TestResponse, TestServer, encode_json};

pub const APPROVER_NONCE: [u8; PAIRING_NONCE_LENGTH] =
    [7; PAIRING_NONCE_LENGTH];
pub const JOINER_NONCE: [u8; PAIRING_NONCE_LENGTH] = [8; PAIRING_NONCE_LENGTH];

pub fn approve_path(code: &str) -> String {
    format!("/pairing/sessions/{code}/approve")
}

pub fn commitment_path(code: &str) -> String {
    format!("/pairing/sessions/{code}/commitment")
}

pub fn approver_nonce_path(code: &str) -> String {
    format!("/pairing/sessions/{code}/nonce")
}

pub fn joiner_nonce_path(join_id: Uuid) -> String {
    format!("/pairing/join/{join_id}/nonce")
}

pub async fn read_join_status(test: &TestServer, join_id: Uuid) -> JoinStatus {
    let path = format!("/pairing/join/{join_id}");
    let response = test.send_unsigned(Method::GET, &path, Vec::new()).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

pub fn parse_code(code_text: &str) -> PairingCode {
    PairingCode::parse(code_text).expect("the server shows valid codes")
}

pub fn commitment_for(
    account: &Account,
    code_text: &str,
    approver_nonce: &[u8],
) -> PairingCommitment {
    let approver = PairingPublicKeys::of_identity(&account.owner);
    let code = parse_code(code_text);
    PairingCommitment {
        commitment: commit_to_approver_nonce(&code, &approver, approver_nonce),
    }
}

pub async fn open_session(
    test: &TestServer,
    account: &Account,
) -> PairingSessionCreated {
    let response = test.post_empty(&account.owner, PAIRING_SESSIONS).await;
    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    response.json()
}

pub async fn start_pairing(
    test: &TestServer,
    account: &Account,
) -> PairingSessionCreated {
    let created = open_session(test, account).await;
    let commitment = commitment_for(account, &created.code, &APPROVER_NONCE);
    let response = test
        .post(&account.owner, &commitment_path(&created.code), &commitment)
        .await;
    assert_eq!(response.status, StatusCode::NO_CONTENT, "{response:?}");
    created
}

pub async fn send_join(
    test: &TestServer,
    code: &str,
    registration: DeviceRegistration,
) -> TestResponse {
    let join_request = JoinRequest {
        code: code.to_owned(),
        device: registration,
    };
    test.send_unsigned(Method::POST, PAIRING_JOIN, encode_json(&join_request))
        .await
}

pub async fn send_joiner_nonce(
    test: &TestServer,
    join_id: Uuid,
    nonce: &[u8],
) -> TestResponse {
    let body = PairingNonce {
        nonce: nonce.to_vec(),
    };
    test.send_unsigned(
        Method::POST,
        &joiner_nonce_path(join_id),
        encode_json(&body),
    )
    .await
}

pub async fn join_session(
    test: &TestServer,
    code: &str,
    registration: DeviceRegistration,
) -> JoinAccepted {
    let response = send_join(test, code, registration).await;
    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    let accepted: JoinAccepted = response.json();
    let nonce_response =
        send_joiner_nonce(test, accepted.join_id, &JOINER_NONCE).await;
    assert_eq!(
        nonce_response.status,
        StatusCode::NO_CONTENT,
        "{nonce_response:?}"
    );
    accepted
}

pub async fn reveal_approver_nonce(
    test: &TestServer,
    account: &Account,
    code: &str,
    nonce: &[u8],
) -> TestResponse {
    let body = PairingNonce {
        nonce: nonce.to_vec(),
    };
    test.post(&account.owner, &approver_nonce_path(code), &body)
        .await
}

pub fn transcript_for(
    account: &Account,
    code_text: &str,
    registration: &DeviceRegistration,
) -> PairingTranscript {
    PairingTranscript {
        code: parse_code(code_text),
        joiner: PairingPublicKeys {
            signing_public_key: registration.signing_public_key.clone(),
            sealing_public_key: registration.sealing_public_key.clone(),
        },
        approver: PairingPublicKeys::of_identity(&account.owner),
        joiner_nonce: JOINER_NONCE.to_vec(),
        approver_nonce: APPROVER_NONCE.to_vec(),
    }
}

pub fn approval_signed_over(
    account: &Account,
    transcript: &PairingTranscript,
) -> ApprovePairingRequest {
    ApprovePairingRequest {
        sealed_workspace_keys: vec![SealedWorkspaceKey {
            workspace_id: account.workspace_id,
            sealed_key: SEALED_KEY_BYTES.to_vec(),
        }],
        approval_signature: transcript
            .sign_approval(&account.owner)
            .expect("the owner approves its own transcript"),
    }
}

pub fn approval_for(
    account: &Account,
    code_text: &str,
    registration: &DeviceRegistration,
) -> ApprovePairingRequest {
    let transcript = transcript_for(account, code_text, registration);
    approval_signed_over(account, &transcript)
}

pub async fn approve_session(
    test: &TestServer,
    account: &Account,
    code: &str,
    registration: &DeviceRegistration,
) -> TestResponse {
    let revealed =
        reveal_approver_nonce(test, account, code, &APPROVER_NONCE).await;
    assert_eq!(revealed.status, StatusCode::NO_CONTENT, "{revealed:?}");
    let approval = approval_for(account, code, registration);
    test.post(&account.owner, &approve_path(code), &approval)
        .await
}

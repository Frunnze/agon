use axum::http::StatusCode;
use chrono::TimeDelta;
use orchestration_api::accounts::JoinStatus;
use orchestration_core::device::DeviceRole;
use orchestration_security::pairing::PAIRING_SESSION_LIFETIME;
use proptest::prelude::*;

use crate::fixtures::{
    Account, create_account, identity_from_seed, pair_device, registration_for,
};
use crate::pairing_fixtures::{
    approve_session, join_session, read_join_status, send_join, start_pairing,
};
use crate::test_client::{TestResponse, TestServer, block_on};

const CANCEL_CASES: u32 = 8;
const JOINING_SEED: u8 = 4;
const OTHER_DEVICE_SEED: u8 = 5;
const LATE_JOINING_SEED: u8 = 6;
const JOINING_NAME: &str = "mac-mini";
const OTHER_DEVICE_NAME: &str = "office-mac";
const EXPIRED_MESSAGE: &str = "the pairing session has expired";
const UNKNOWN_CODE_PATTERN: &str = "[0-9A-Za-z]{1,12}";

fn cancel_path(code: &str) -> String {
    format!("/pairing/sessions/{code}/cancel")
}

fn session_path(code: &str) -> String {
    format!("/pairing/sessions/{code}")
}

fn reject_path(code: &str) -> String {
    format!("/pairing/sessions/{code}/reject")
}

#[derive(Clone, Copy, Debug)]
enum CodeTyping {
    AsShown,
    WithoutDash,
    Lowercase,
    LowercaseWithoutDash,
}

fn any_code_typing() -> impl Strategy<Value = CodeTyping> {
    prop_oneof![
        Just(CodeTyping::AsShown),
        Just(CodeTyping::WithoutDash),
        Just(CodeTyping::Lowercase),
        Just(CodeTyping::LowercaseWithoutDash),
    ]
}

fn type_code(display_code: &str, typing: CodeTyping) -> String {
    match typing {
        CodeTyping::AsShown => display_code.to_owned(),
        CodeTyping::WithoutDash => display_code.replace('-', ""),
        CodeTyping::Lowercase => display_code.to_lowercase(),
        CodeTyping::LowercaseWithoutDash => {
            display_code.replace('-', "").to_lowercase()
        }
    }
}

fn any_role() -> impl Strategy<Value = DeviceRole> {
    prop_oneof![
        Just(DeviceRole::Client),
        Just(DeviceRole::Runner),
        Just(DeviceRole::ClientAndRunner),
    ]
}

async fn cancel_session(
    test: &TestServer,
    account: &Account,
    code: &str,
) -> TestResponse {
    test.post_empty(&account.owner, &cancel_path(code)).await
}

async fn try_joining(test: &TestServer, code: &str) -> TestResponse {
    let joining = identity_from_seed(LATE_JOINING_SEED);
    let registration =
        registration_for(&joining, JOINING_NAME, DeviceRole::Runner);
    send_join(test, code, registration).await
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CANCEL_CASES))]

    #[test]
    fn test_cancel_pairing_property_ends_the_session_for_everyone(
        typing in any_code_typing(),
    ) {
        let test = TestServer::start();
        let statuses = block_on(async {
            let account = create_account(&test).await;
            let session = start_pairing(&test, &account).await;
            let typed_code = type_code(&session.code, typing);
            let cancelled =
                cancel_session(&test, &account, &typed_code).await;
            let shown = test
                .get(&account.owner, &session_path(&session.code))
                .await;
            let joined = try_joining(&test, &session.code).await;
            let cancelled_again =
                cancel_session(&test, &account, &session.code).await;
            [
                cancelled.status,
                shown.status,
                joined.status,
                cancelled_again.status,
            ]
        });

        prop_assert_eq!(statuses[0], StatusCode::NO_CONTENT);
        prop_assert_eq!(statuses[1], StatusCode::NOT_FOUND);
        prop_assert_eq!(statuses[2], StatusCode::NOT_FOUND);
        prop_assert_eq!(statuses[3], StatusCode::NOT_FOUND);
    }

    #[test]
    fn test_cancel_pairing_property_tells_a_waiting_joiner_it_was_rejected(
        joining_seed in 10_u8..=255,
    ) {
        let test = TestServer::start();
        let (cancel_status, join_status) = block_on(async {
            let account = create_account(&test).await;
            let session = start_pairing(&test, &account).await;
            let joining = identity_from_seed(joining_seed);
            let registration =
                registration_for(&joining, JOINING_NAME, DeviceRole::Runner);
            let accepted =
                join_session(&test, &session.code, registration).await;
            let cancelled =
                cancel_session(&test, &account, &session.code).await;
            let join_status =
                read_join_status(&test, accepted.join_id).await;
            (cancelled.status, join_status)
        });

        prop_assert_eq!(cancel_status, StatusCode::NO_CONTENT);
        prop_assert_eq!(join_status, JoinStatus::Rejected);
    }

    #[test]
    fn test_cancel_pairing_property_refuses_expired_sessions(
        extra_seconds in 0_i64..10_000,
    ) {
        let test = TestServer::start();
        let response = block_on(async {
            let account = create_account(&test).await;
            let session = start_pairing(&test, &account).await;
            test.clock.advance(
                PAIRING_SESSION_LIFETIME + TimeDelta::seconds(extra_seconds),
            );
            cancel_session(&test, &account, &session.code).await
        });

        prop_assert_eq!(response.status, StatusCode::CONFLICT);
        prop_assert_eq!(response.error_message(), EXPIRED_MESSAGE);
    }

    #[test]
    fn test_cancel_pairing_property_refuses_finished_sessions(
        approve_first in any::<bool>(),
    ) {
        let test = TestServer::start();
        let (decision_status, cancel_status) = block_on(async {
            let account = create_account(&test).await;
            let session = start_pairing(&test, &account).await;
            let joining = identity_from_seed(JOINING_SEED);
            let registration =
                registration_for(&joining, JOINING_NAME, DeviceRole::Runner);
            join_session(&test, &session.code, registration.clone()).await;
            let decided = if approve_first {
                approve_session(&test, &account, &session.code, &registration)
                    .await
            } else {
                test.post_empty(&account.owner, &reject_path(&session.code))
                    .await
            };
            let cancelled =
                cancel_session(&test, &account, &session.code).await;
            (decided.status, cancelled.status)
        });

        prop_assert!(decision_status.is_success());
        prop_assert_eq!(cancel_status, StatusCode::NOT_FOUND);
    }

    #[test]
    fn test_cancel_pairing_property_only_the_starting_device_may_cancel(
        role in any_role(),
    ) {
        let test = TestServer::start();
        let (cancel_status, shown_status) = block_on(async {
            let account = create_account(&test).await;
            let other = identity_from_seed(OTHER_DEVICE_SEED);
            pair_device(&test, &account, &other, OTHER_DEVICE_NAME, role)
                .await;
            let session = start_pairing(&test, &account).await;
            let cancelled =
                test.post_empty(&other, &cancel_path(&session.code)).await;
            let shown = test
                .get(&account.owner, &session_path(&session.code))
                .await;
            (cancelled.status, shown.status)
        });

        prop_assert_eq!(cancel_status, StatusCode::FORBIDDEN);
        prop_assert_eq!(shown_status, StatusCode::OK);
    }

    #[test]
    fn test_cancel_pairing_property_unknown_codes_give_not_found(
        code in UNKNOWN_CODE_PATTERN,
    ) {
        let test = TestServer::start();
        let response = block_on(async {
            let account = create_account(&test).await;
            cancel_session(&test, &account, &code).await
        });

        prop_assert_eq!(response.status, StatusCode::NOT_FOUND);
    }
}

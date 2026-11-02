use axum::http::{Method, StatusCode};
use orchestration_core::identifiers::WorkspaceId;
use proptest::prelude::*;
use serde_json::Value;
use uuid::Uuid;

use crate::fixtures::{account_request_for, identity_from_seed};
use crate::test_client::{TestResponse, TestServer, block_on, encode_json};

const FIRST_SEED: u8 = 90;
const GROUP_SEPARATOR: char = '-';
const SYMBOLS_PER_GROUP: usize = 3;
const GROUP_COUNT: usize = 4;

async fn post_account(
    test: &TestServer,
    setup_code: String,
    seed: u8,
) -> TestResponse {
    let identity = identity_from_seed(seed);
    let workspace_id = WorkspaceId(Uuid::new_v4());
    let request = account_request_for(&identity, workspace_id, setup_code);
    let body = encode_json(&request);
    test.send_unsigned(Method::POST, "/accounts", body).await
}

fn account_exists(test: &TestServer) -> bool {
    let state = test.server.snapshot_state().expect("the state is readable");
    !state.devices.is_empty()
}

fn canonical_spelling(code: &str) -> String {
    code.replace(GROUP_SEPARATOR, "").to_uppercase()
}

fn spell_code(code: &str, spelling: u8) -> String {
    match spelling {
        0 => code.to_owned(),
        1 => code.to_lowercase(),
        _ => code.replace(GROUP_SEPARATOR, " "),
    }
}

fn wrong_code_strategy() -> impl Strategy<Value = String> {
    prop_oneof!["\\PC{0,20}", "[0-9A-HJKMNP-TV-Z]{12}"]
}

fn replacement_strategy() -> impl Strategy<Value = Option<Value>> {
    prop_oneof![
        Just(None),
        Just(Some(Value::Null)),
        any::<bool>().prop_map(|flag| Some(Value::Bool(flag))),
        any::<i64>().prop_map(|number| Some(Value::from(number))),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(24))]

    #[test]
    fn test_create_account_property_wrong_codes_never_create_an_account(
        offered_code in wrong_code_strategy(),
    ) {
        let test = TestServer::start();
        let real_code = test.read_setup_code();
        prop_assume!(
            canonical_spelling(&offered_code) != canonical_spelling(&real_code)
        );

        let wrong = block_on(post_account(&test, offered_code, FIRST_SEED));
        let has_account_after_wrong_code = account_exists(&test);
        let right = block_on(post_account(&test, real_code, FIRST_SEED));

        prop_assert_eq!(wrong.status, StatusCode::FORBIDDEN);
        prop_assert!(!has_account_after_wrong_code);
        prop_assert_eq!(right.status, StatusCode::CREATED);
    }

    #[test]
    fn test_create_account_property_missing_codes_never_create_an_account(
        replacement in replacement_strategy(),
    ) {
        let test = TestServer::start();
        let identity = identity_from_seed(FIRST_SEED);
        let workspace_id = WorkspaceId(Uuid::new_v4());
        let setup_code = test.read_setup_code();
        let request = account_request_for(&identity, workspace_id, setup_code);
        let mut body = serde_json::to_value(&request).expect("encodes");
        let fields = body.as_object_mut().expect("the request is an object");
        match replacement {
            Some(value) => fields.insert("setup_code".to_owned(), value),
            None => fields.remove("setup_code"),
        };

        let response = block_on(test.send_unsigned(
            Method::POST,
            "/accounts",
            encode_json(&body),
        ));

        prop_assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
        prop_assert!(!account_exists(&test));
    }

    #[test]
    fn test_create_account_property_right_code_works_exactly_once(
        spelling in 0_u8..3,
        extra_attempts in 1_u8..4,
    ) {
        let test = TestServer::start();
        let offered_code = spell_code(&test.read_setup_code(), spelling);
        let statuses = block_on(async {
            let mut statuses = Vec::new();
            for attempt in 0..=extra_attempts {
                let seed = FIRST_SEED + attempt;
                let response =
                    post_account(&test, offered_code.clone(), seed).await;
                statuses.push(response.status);
            }
            statuses
        });
        let state = test.server.snapshot_state().expect("readable");

        prop_assert_eq!(statuses[0], StatusCode::CREATED);
        for later_status in &statuses[1..] {
            prop_assert_eq!(*later_status, StatusCode::FORBIDDEN);
        }
        prop_assert_eq!(state.devices.len(), 1);
        prop_assert!(!test.setup_code_path().exists());
    }
}

#[test]
fn the_setup_code_is_shown_once_in_groups_of_three() {
    let test = TestServer::start();
    let saved_code = test.read_setup_code();
    let groups: Vec<&str> = saved_code.split(GROUP_SEPARATOR).collect();

    assert_eq!(
        test.server.newly_issued_setup_code(),
        Some(saved_code.as_str())
    );
    assert_eq!(groups.len(), GROUP_COUNT);
    assert!(groups.iter().all(|group| group.len() == SYMBOLS_PER_GROUP));
}

#[cfg(unix)]
#[test]
fn only_the_owner_can_read_the_setup_code() {
    use std::os::unix::fs::PermissionsExt;

    let test = TestServer::start();
    let metadata = std::fs::metadata(test.setup_code_path())
        .expect("the setup code file exists");
    let permission_bits = metadata.permissions().mode() & 0o777;

    assert_eq!(permission_bits, 0o600);
}

#[test]
fn restarting_before_setup_keeps_the_code_without_showing_it_again() {
    let test = TestServer::start();
    let first_code = test.read_setup_code();

    let restarted = test.restart();

    assert_eq!(restarted.read_setup_code(), first_code);
    assert_eq!(restarted.server.newly_issued_setup_code(), None);
}

#[test]
fn restarting_after_setup_issues_no_code() {
    let test = TestServer::start();
    let used_code = test.read_setup_code();
    let created = block_on(post_account(&test, used_code.clone(), FIRST_SEED));

    let restarted = test.restart();
    let second_seed = FIRST_SEED + 1;
    let retried = block_on(post_account(&restarted, used_code, second_seed));

    assert_eq!(created.status, StatusCode::CREATED);
    assert!(!restarted.setup_code_path().exists());
    assert_eq!(restarted.server.newly_issued_setup_code(), None);
    assert_eq!(retried.status, StatusCode::FORBIDDEN);
}

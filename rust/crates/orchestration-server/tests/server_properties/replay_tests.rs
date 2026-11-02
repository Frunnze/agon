use std::sync::Arc;

use axum::http::{Method, StatusCode};
use proptest::prelude::*;

use crate::fixtures::create_account;
use crate::test_client::{TestServer, block_on, sign_headers};

const IDENTICAL_REQUEST_COUNT: usize = 32;
const READ_PATHS: [&str; 4] = ["/projects", "/tasks", "/workflows", "/runs"];
const HEX_DIGITS: &str = "0123456789abcdef";

fn flip_hex_digit(text: &str, position: usize) -> String {
    let mut characters: Vec<char> = text.chars().collect();
    let index = position % characters.len();
    let replacement = HEX_DIGITS
        .chars()
        .find(|digit| *digit != characters[index])
        .unwrap_or('0');
    characters[index] = replacement;
    characters.into_iter().collect()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(8))]

    #[test]
    fn test_signed_request_property_a_reused_nonce_is_rejected(
        path in proptest::sample::select(READ_PATHS.to_vec()),
    ) {
        let test = TestServer::start();
        let (first, second) = block_on(async {
            let account = create_account(&test).await;
            let header_values = sign_headers(
                &account.owner,
                &Method::GET,
                path,
                &[],
                test.now(),
            );
            let headers = &header_values;
            let first =
                test.send_with_headers(Method::GET, path, Vec::new(), headers);
            let first = first.await;
            let second =
                test.send_with_headers(Method::GET, path, Vec::new(), headers);
            (first, second.await)
        });

        prop_assert_eq!(first.status, StatusCode::OK);
        prop_assert_eq!(second.status, StatusCode::UNAUTHORIZED);
        let message = second.error_message();
        prop_assert_eq!(message, "the request was already used");
    }

    #[test]
    fn test_signed_request_property_a_tampered_nonce_is_rejected(
        position in 0_usize..32,
    ) {
        let test = TestServer::start();
        let response = block_on(async {
            let account = create_account(&test).await;
            let mut header_values = sign_headers(
                &account.owner,
                &Method::GET,
                "/projects",
                &[],
                test.now(),
            );
            let tampered = flip_hex_digit(&header_values.nonce, position);
            header_values.nonce = tampered;
            test.send_with_headers(
                Method::GET,
                "/projects",
                Vec::new(),
                &header_values,
            )
            .await
        });

        prop_assert_eq!(response.status, StatusCode::UNAUTHORIZED);
    }
}

#[test]
fn identical_requests_signed_in_the_same_instant_all_succeed() {
    let test = Arc::new(TestServer::start());
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(4)
        .enable_all()
        .build()
        .expect("the runtime starts");
    let statuses = runtime.block_on(async {
        let account = create_account(&test).await;
        let owner = Arc::new(account.owner);
        let signed_at = test.now();
        let mut handles = Vec::new();
        for _ in 0..IDENTICAL_REQUEST_COUNT {
            let shared_test = Arc::clone(&test);
            let shared_owner = Arc::clone(&owner);
            handles.push(tokio::spawn(async move {
                let header_values = sign_headers(
                    &shared_owner,
                    &Method::GET,
                    "/projects",
                    &[],
                    signed_at,
                );
                shared_test
                    .send_with_headers(
                        Method::GET,
                        "/projects",
                        Vec::new(),
                        &header_values,
                    )
                    .await
                    .status
            }));
        }
        let mut statuses = Vec::new();
        for handle in handles {
            statuses.push(handle.await.expect("the request task finishes"));
        }
        statuses
    });

    assert_eq!(statuses.len(), IDENTICAL_REQUEST_COUNT);
    assert!(statuses.iter().all(|status| *status == StatusCode::OK));
}

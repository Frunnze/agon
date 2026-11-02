use std::fmt::Write;

use axum::http::{Method, StatusCode};
use chrono::TimeDelta;
use orchestration_api::accounts::{RevokeDeviceRequest, revocation_statement};
use orchestration_core::device::DeviceRole;
use orchestration_security::request_signing::REQUEST_TIMESTAMP_WINDOW;
use proptest::prelude::*;

use crate::fixtures::{create_account, identity_from_seed, pair_device};
use crate::test_client::{TestServer, block_on, sign_headers};

const PROTECTED_ROUTES: [(&str, &str); 19] = [
    ("GET", "/accounts"),
    ("GET", "/devices"),
    ("GET", "/workspaces"),
    ("GET", "/projects"),
    ("GET", "/workflows"),
    ("GET", "/skills"),
    ("GET", "/rules"),
    ("GET", "/tasks"),
    ("GET", "/runs"),
    ("GET", "/runners"),
    ("GET", "/approvals"),
    ("GET", "/audit"),
    ("GET", "/events?after=0"),
    ("POST", "/pairing/sessions"),
    ("POST", "/pairing/sessions/4F7K2Q/cancel"),
    ("POST", "/pairing/sessions/4F7K2Q/commitment"),
    ("POST", "/pairing/sessions/4F7K2Q/nonce"),
    ("POST", "/runners/claim"),
    ("POST", "/runners/heartbeat"),
];
const RUNNER_SEED: u8 = 2;
const STRANGER_SEED: u8 = 3;

fn protected_route() -> impl Strategy<Value = (Method, String)> {
    (0..PROTECTED_ROUTES.len()).prop_map(|position| {
        let (method_text, path) = PROTECTED_ROUTES[position];
        let method = Method::from_bytes(method_text.as_bytes())
            .expect("route methods are valid");
        (method, path.to_owned())
    })
}

fn is_rejected_as_unauthenticated(status: StatusCode) -> bool {
    status == StatusCode::UNAUTHORIZED
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(24))]

    #[test]
    fn test_signed_request_property_unsigned_requests_are_always_rejected(
        (method, path) in protected_route(),
        body in proptest::collection::vec(any::<u8>(), 0..64),
    ) {
        let test = TestServer::start();
        let response = block_on(async {
            create_account(&test).await;
            test.send_unsigned(method, &path, body).await
        });

        prop_assert!(is_rejected_as_unauthenticated(response.status));
        prop_assert_ne!(response.error_message(), "");
    }

    #[test]
    fn test_signed_request_property_tampered_requests_are_rejected(
        tamper_choice in 0_u8..4,
        tamper_byte in 1_u8..=255,
    ) {
        let test = TestServer::start();
        let response = block_on(async {
            let account = create_account(&test).await;
            let body = b"{}".to_vec();
            let mut header_values = sign_headers(
                &account.owner,
                &Method::GET,
                "/projects",
                &body,
                test.now(),
            );
            let mut sent_path = "/projects".to_owned();
            let mut sent_body = body;
            match tamper_choice {
                0 => sent_path = "/projects?after=1".to_owned(),
                1 => sent_body.push(tamper_byte),
                2 => {
                    let mut signature_bytes =
                        hex_decode(&header_values.signature);
                    signature_bytes[0] ^= tamper_byte;
                    header_values.signature = hex_encode(&signature_bytes);
                }
                _ => {
                    header_values.timestamp =
                        header_values.timestamp.replacen('2', "1", 1);
                }
            }
            test.send_with_headers(
                Method::GET,
                &sent_path,
                sent_body,
                &header_values,
            )
            .await
        });

        prop_assert!(is_rejected_as_unauthenticated(response.status));
    }

    #[test]
    fn test_signed_request_property_rejects_timestamps_outside_window(
        extra_seconds in 1_i64..100_000,
        is_in_future in any::<bool>(),
    ) {
        let test = TestServer::start();
        let response = block_on(async {
            let account = create_account(&test).await;
            let distance =
                REQUEST_TIMESTAMP_WINDOW + TimeDelta::seconds(extra_seconds);
            let timestamp = if is_in_future {
                test.now() + distance
            } else {
                test.now() - distance
            };
            let header_values = sign_headers(
                &account.owner,
                &Method::GET,
                "/projects",
                &[],
                timestamp,
            );
            test.send_with_headers(
                Method::GET,
                "/projects",
                Vec::new(),
                &header_values,
            )
            .await
        });

        prop_assert!(is_rejected_as_unauthenticated(response.status));
    }

    #[test]
    fn test_signed_request_property_accepts_timestamps_inside_window(
        offset_seconds in -299_i64..299,
    ) {
        let test = TestServer::start();
        let response = block_on(async {
            let account = create_account(&test).await;
            let timestamp = test.now() + TimeDelta::seconds(offset_seconds);
            let header_values = sign_headers(
                &account.owner,
                &Method::GET,
                "/projects",
                &[],
                timestamp,
            );
            test.send_with_headers(
                Method::GET,
                "/projects",
                Vec::new(),
                &header_values,
            )
            .await
        });

        prop_assert_eq!(response.status, StatusCode::OK);
    }

    #[test]
    fn test_signed_request_property_revoked_devices_are_always_rejected(
        (method, path) in protected_route(),
    ) {
        let test = TestServer::start();
        let response = block_on(async {
            let account = create_account(&test).await;
            let runner = identity_from_seed(RUNNER_SEED);
            let device = pair_device(
                &test,
                &account,
                &runner,
                "mac-studio",
                DeviceRole::ClientAndRunner,
            )
            .await;
            let revoke_request = RevokeDeviceRequest {
                approval_signature: account
                    .owner
                    .sign(&revocation_statement(&device.id)),
            };
            let revoke_path = format!("/devices/{}/revoke", device.id.0);
            let revoke_response =
                test.post(&account.owner, &revoke_path, &revoke_request).await;
            assert_eq!(revoke_response.status, StatusCode::OK);
            test.send_signed(&runner, method, &path, Vec::new()).await
        });

        prop_assert_eq!(response.status, StatusCode::FORBIDDEN);
    }

    #[test]
    fn test_signed_request_property_unknown_devices_are_rejected(
        (method, path) in protected_route(),
    ) {
        let test = TestServer::start();
        let response = block_on(async {
            create_account(&test).await;
            let stranger = identity_from_seed(STRANGER_SEED);
            test.send_signed(&stranger, method, &path, Vec::new()).await
        });

        prop_assert!(is_rejected_as_unauthenticated(response.status));
    }
}

#[test]
fn replayed_requests_are_rejected() {
    let test = TestServer::start();
    let (first_status, replay_status) = block_on(async {
        let account = create_account(&test).await;
        let header_values = sign_headers(
            &account.owner,
            &Method::GET,
            "/projects",
            &[],
            test.now(),
        );
        let first_response = test
            .send_with_headers(
                Method::GET,
                "/projects",
                Vec::new(),
                &header_values,
            )
            .await;
        let replay_response = test
            .send_with_headers(
                Method::GET,
                "/projects",
                Vec::new(),
                &header_values,
            )
            .await;
        (first_response.status, replay_response.status)
    });

    assert_eq!(first_status, StatusCode::OK);
    assert_eq!(replay_status, StatusCode::UNAUTHORIZED);
}

#[test]
fn health_needs_no_signature() {
    let test = TestServer::start();
    let response =
        block_on(test.send_unsigned(Method::GET, "/health", Vec::new()));

    assert_eq!(response.status, StatusCode::OK);
}

fn hex_decode(text: &str) -> Vec<u8> {
    (0..text.len())
        .step_by(2)
        .map(|position| {
            u8::from_str_radix(&text[position..position + 2], 16)
                .expect("signature header is hex")
        })
        .collect()
}

fn hex_encode(bytes: &[u8]) -> String {
    let mut text = String::new();
    for byte in bytes {
        write!(text, "{byte:02x}").expect("writing to a string works");
    }
    text
}

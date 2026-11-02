use std::io::{Read, Write};
use std::net::TcpStream;
use std::sync::Arc;

use axum::http::{Method, StatusCode};
use orchestration_core::identifiers::WorkspaceId;
use orchestration_server::serve_app_server;
use proptest::prelude::*;
use uuid::Uuid;

use crate::fixtures::{account_request_for, identity_from_seed};
use crate::test_client::{TestServer, block_on, encode_json};

const ACCOUNT_SEED: u8 = 120;
const LOOPBACK_ANY_PORT: &str = "127.0.0.1:0";
const HEALTHY_ANSWER_START: &str = "HTTP/1.1 200";
const HOSTING_CASES: u32 = 8;

fn read_health_answer(authority: &str) -> String {
    let mut connection =
        TcpStream::connect(authority).expect("the server accepts");
    let request = format!(
        "GET /health HTTP/1.1\r\nHost: {authority}\r\n\
         Connection: close\r\n\r\n"
    );
    connection
        .write_all(request.as_bytes())
        .expect("the request is sent");
    let mut answer = String::new();
    connection
        .read_to_string(&mut answer)
        .expect("the answer is read");
    answer
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOSTING_CASES))]

    #[test]
    fn test_read_setup_code_property_shows_the_code_until_it_is_used(
        seed_offset in 0u8..8,
    ) {
        let test = TestServer::start();
        let saved_code = test.read_setup_code();

        let shown_before = test.server.read_setup_code();
        let identity = identity_from_seed(ACCOUNT_SEED + seed_offset);
        let workspace_id = WorkspaceId(Uuid::new_v4());
        let shown_code =
            shown_before.clone().ok().flatten().unwrap_or_default();
        let request = account_request_for(&identity, workspace_id, shown_code);
        let created = block_on(test.send_unsigned(
            Method::POST,
            "/accounts",
            encode_json(&request),
        ));
        let shown_after = test.server.read_setup_code();

        prop_assert_eq!(shown_before, Ok(Some(saved_code)));
        prop_assert_eq!(created.status, StatusCode::CREATED);
        prop_assert_eq!(shown_after, Ok(None));
    }
}

#[test]
fn test_serve_app_server_property_answers_until_the_task_stops() {
    let test = TestServer::start();
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("the runtime starts");
    let listener = runtime
        .block_on(tokio::net::TcpListener::bind(LOOPBACK_ANY_PORT))
        .expect("the listener binds");
    let authority = listener
        .local_addr()
        .expect("the listener has an address")
        .to_string();

    let serving =
        runtime.spawn(serve_app_server(listener, Arc::clone(&test.server)));
    let answer = read_health_answer(&authority);
    serving.abort();
    let stopped = runtime.block_on(serving);

    assert!(answer.starts_with(HEALTHY_ANSWER_START), "{answer}");
    assert!(stopped.is_err_and(|ending| ending.is_cancelled()));
}

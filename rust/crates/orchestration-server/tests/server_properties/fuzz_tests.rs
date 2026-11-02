use std::fmt::Write;

use axum::http::{Method, StatusCode};
use orchestration_api::updates::ApiErrorBody;
use proptest::prelude::*;
use serde_json::{Map, Value};

use crate::fixtures::{Account, create_account};
use crate::test_client::{TestResponse, TestServer, block_on, encode_json};

const WRITE_ROUTES: [(&str, &str); 24] = [
    ("POST", "/accounts"),
    ("POST", "/pairing/join"),
    ("POST", "/pairing/join/{random}/nonce"),
    ("POST", "/pairing/sessions/4F7K2Q/commitment"),
    ("POST", "/pairing/sessions/4F7K2Q/nonce"),
    ("POST", "/pairing/sessions/4F7K2Q/approve"),
    ("POST", "/devices/{device}/revoke"),
    ("POST", "/workspaces"),
    ("POST", "/workspaces/{workspace}/devices"),
    ("POST", "/projects"),
    ("POST", "/projects/{random}/repositories"),
    ("POST", "/workflows"),
    ("PUT", "/workflows/{random}"),
    ("POST", "/workflows/{random}/signature"),
    ("POST", "/skills"),
    ("POST", "/rules"),
    ("PUT", "/rules/{random}/enabled"),
    ("POST", "/tasks"),
    ("POST", "/runs/{random}/messages"),
    ("POST", "/runs/{random}/events"),
    ("POST", "/runners/heartbeat"),
    ("PUT", "/runners/{device}/accepting"),
    ("POST", "/approvals"),
    ("POST", "/approvals/{random}/decision"),
];
const UUID_PATTERN: &str =
    "[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-8[0-9a-f]{3}-[0-9a-f]{12}";
const FIELD_NAMES: [&str; 18] = [
    "nonce",
    "commitment",
    "project",
    "task",
    "workflow",
    "events",
    "decision",
    "repository",
    "rule",
    "skill",
    "device",
    "code",
    "enabled",
    "labels",
    "slots_total",
    "start",
    "message",
    "workspace_id",
];
const DEFINED_STATUSES: [StatusCode; 8] = [
    StatusCode::OK,
    StatusCode::CREATED,
    StatusCode::NO_CONTENT,
    StatusCode::UNAUTHORIZED,
    StatusCode::FORBIDDEN,
    StatusCode::NOT_FOUND,
    StatusCode::CONFLICT,
    StatusCode::UNPROCESSABLE_ENTITY,
];

fn json_leaf() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        any::<bool>().prop_map(Value::Bool),
        any::<i64>().prop_map(Value::from),
        "\\PC{0,24}".prop_map(Value::String),
    ]
}

fn json_container(
    inner: BoxedStrategy<Value>,
) -> impl Strategy<Value = Value> {
    let field_name = (0..FIELD_NAMES.len()).prop_map(field_name_at);
    prop_oneof![
        proptest::collection::vec(inner.clone(), 0..5).prop_map(Value::Array),
        proptest::collection::btree_map(field_name, inner, 0..5)
            .prop_map(object_from_fields),
    ]
}

fn field_name_at(position: usize) -> String {
    FIELD_NAMES[position].to_owned()
}

fn object_from_fields(
    fields: std::collections::BTreeMap<String, Value>,
) -> Value {
    Value::Object(fields.into_iter().collect::<Map<String, Value>>())
}

fn json_value() -> impl Strategy<Value = Value> {
    json_leaf().prop_recursive(3, 32, 5, json_container)
}

fn percent_encode(text: &str) -> String {
    let mut encoded = String::new();
    for byte in text.bytes() {
        write!(encoded, "%{byte:02X}").expect("writing to a string works");
    }
    encoded
}

fn route_path(template: &str, account: &Account, random: &str) -> String {
    template
        .replace("{device}", &account.owner.device_id().0)
        .replace("{workspace}", &account.workspace_id.0.to_string())
        .replace("{random}", random)
}

fn assert_defined_response(response: &TestResponse) {
    assert!(
        DEFINED_STATUSES.contains(&response.status),
        "undefined status {response:?}"
    );
    if response.status.is_client_error() {
        let error_body: ApiErrorBody = response.json();
        assert_ne!(error_body.message, "");
    }
}

async fn send_to_route(
    test: &TestServer,
    account: &Account,
    route_position: usize,
    random: &str,
    body: Vec<u8>,
) -> TestResponse {
    let (method_text, template) = WRITE_ROUTES[route_position];
    let method = Method::from_bytes(method_text.as_bytes())
        .expect("route methods are valid");
    let path = route_path(template, account, random);
    test.send_signed(&account.owner, method, &path, body).await
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(96))]

    #[test]
    fn test_router_property_arbitrary_json_never_breaks_the_server(
        route_position in 0..WRITE_ROUTES.len(),
        body in json_value(),
        random in UUID_PATTERN,
    ) {
        let test = TestServer::start();
        let response = block_on(async {
            let account = create_account(&test).await;
            let encoded_body = encode_json(&body);
            send_to_route(
                &test,
                &account,
                route_position,
                &random,
                encoded_body,
            )
            .await
        });

        assert_defined_response(&response);
    }

    #[test]
    fn test_router_property_arbitrary_bytes_never_break_the_server(
        route_position in 0..WRITE_ROUTES.len(),
        body in proptest::collection::vec(any::<u8>(), 0..128),
        random in "\\PC{0,12}",
    ) {
        let encoded_random = percent_encode(&random);
        let test = TestServer::start();
        let response = block_on(async {
            let account = create_account(&test).await;
            let path_value = encoded_random.as_str();
            send_to_route(&test, &account, route_position, path_value, body)
                .await
        });

        assert_defined_response(&response);
    }
}

#[test]
fn unknown_routes_answer_with_an_error_body() {
    let test = TestServer::start();
    let response = block_on(async {
        let account = create_account(&test).await;
        test.get(&account.owner, "/no-such-route").await
    });

    assert_eq!(response.status, StatusCode::NOT_FOUND);
    assert_ne!(response.error_message(), "");
}

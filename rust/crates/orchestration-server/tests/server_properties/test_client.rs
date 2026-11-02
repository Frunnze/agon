use std::future::Future;
use std::sync::Arc;
use std::sync::atomic::{AtomicI64, Ordering};
use std::time::Duration;

use axum::Router;
use axum::body::{Body, to_bytes};
use axum::http::{HeaderValue, Method, Request, StatusCode};
use chrono::{DateTime, TimeDelta, Utc};
use orchestration_api::routes::{
    DEVICE_HEADER, NONCE_HEADER, SIGNATURE_HEADER, TIMESTAMP_HEADER,
};
use orchestration_api::updates::ApiErrorBody;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::request_signing::{
    RequestHeaderValues, sign_request,
};
use orchestration_server::{
    Clock, Server, ServerSettings, SharedServer, build_router,
};
use serde::Serialize;
use serde::de::DeserializeOwned;
use tempfile::TempDir;
use tower::ServiceExt;

use crate::manual_clock::ManualClock;

pub const START_TIME_SECONDS: i64 = 1_790_000_000;
pub const SETUP_CODE_FILE_NAME: &str = "setup-code";
pub const TEST_PUBLIC_ADDRESS: &str = "https://orchestration.example";
pub const TEST_LONG_POLL_TIMEOUT: Duration = Duration::from_millis(40);
const RESPONSE_BODY_LIMIT: usize = 64 * 1024 * 1024;

#[derive(Debug)]
pub struct TestResponse {
    pub status: StatusCode,
    pub body: Vec<u8>,
}

impl TestResponse {
    pub fn json<Value: DeserializeOwned>(&self) -> Value {
        serde_json::from_slice(&self.body).unwrap_or_else(|problem| {
            panic!(
                "status {} body {:?} does not decode: {problem}",
                self.status,
                String::from_utf8_lossy(&self.body)
            )
        })
    }

    pub fn error_message(&self) -> String {
        let error_body: ApiErrorBody = self.json();
        error_body.message
    }
}

#[derive(Debug)]
pub struct TestServer {
    pub directory: Arc<TempDir>,
    pub clock: Arc<ManualClock>,
    pub server: SharedServer,
    router: Router,
    sent_request_count: AtomicI64,
}

impl TestServer {
    pub fn start() -> Self {
        Self::start_with_long_poll_timeout(TEST_LONG_POLL_TIMEOUT)
    }

    pub fn start_with_long_poll_timeout(long_poll_timeout: Duration) -> Self {
        let directory = TempDir::new().expect("temporary directory exists");
        let start = DateTime::from_timestamp(START_TIME_SECONDS, 0)
            .expect("start time is valid");
        let clock = Arc::new(ManualClock::starting_at(start));
        Self::open(Arc::new(directory), clock, long_poll_timeout)
    }

    pub fn restart(&self) -> Self {
        Self::open(
            Arc::clone(&self.directory),
            Arc::clone(&self.clock),
            TEST_LONG_POLL_TIMEOUT,
        )
    }

    fn open(
        directory: Arc<TempDir>,
        clock: Arc<ManualClock>,
        long_poll_timeout: Duration,
    ) -> Self {
        let server = open_server(&directory, &clock, long_poll_timeout);
        let router = build_router(Arc::clone(&server));
        Self {
            directory,
            clock,
            server,
            router,
            sent_request_count: AtomicI64::new(0),
        }
    }

    pub fn now(&self) -> DateTime<Utc> {
        self.clock.now()
    }

    pub fn setup_code_path(&self) -> std::path::PathBuf {
        self.directory.path().join(SETUP_CODE_FILE_NAME)
    }

    pub fn read_setup_code(&self) -> String {
        std::fs::read_to_string(self.setup_code_path())
            .expect("the setup code is saved before the account exists")
    }

    pub async fn send_unsigned(
        &self,
        method: Method,
        path: &str,
        body: Vec<u8>,
    ) -> TestResponse {
        let request = build_request(method, path, body, None);
        self.dispatch(request).await
    }

    pub async fn send_with_headers(
        &self,
        method: Method,
        path: &str,
        body: Vec<u8>,
        header_values: &RequestHeaderValues,
    ) -> TestResponse {
        let request = build_request(method, path, body, Some(header_values));
        self.dispatch(request).await
    }

    pub async fn send_signed(
        &self,
        identity: &DeviceIdentity,
        method: Method,
        path: &str,
        body: Vec<u8>,
    ) -> TestResponse {
        let request_number =
            self.sent_request_count.fetch_add(1, Ordering::SeqCst);
        let timestamp = self.now() + TimeDelta::nanoseconds(request_number);
        let header_values =
            sign_headers(identity, &method, path, &body, timestamp);
        self.send_with_headers(method, path, body, &header_values)
            .await
    }

    pub async fn get(
        &self,
        identity: &DeviceIdentity,
        path: &str,
    ) -> TestResponse {
        self.send_signed(identity, Method::GET, path, Vec::new())
            .await
    }

    pub async fn post<Body: Serialize>(
        &self,
        identity: &DeviceIdentity,
        path: &str,
        body: &Body,
    ) -> TestResponse {
        let encoded_body = encode_json(body);
        self.send_signed(identity, Method::POST, path, encoded_body)
            .await
    }

    pub async fn post_empty(
        &self,
        identity: &DeviceIdentity,
        path: &str,
    ) -> TestResponse {
        self.send_signed(identity, Method::POST, path, Vec::new())
            .await
    }

    pub async fn put<Body: Serialize>(
        &self,
        identity: &DeviceIdentity,
        path: &str,
        body: &Body,
    ) -> TestResponse {
        let encoded_body = encode_json(body);
        self.send_signed(identity, Method::PUT, path, encoded_body)
            .await
    }

    pub async fn delete(
        &self,
        identity: &DeviceIdentity,
        path: &str,
    ) -> TestResponse {
        self.send_signed(identity, Method::DELETE, path, Vec::new())
            .await
    }

    pub async fn delete_with_body<Body: Serialize>(
        &self,
        identity: &DeviceIdentity,
        path: &str,
        body: &Body,
    ) -> TestResponse {
        let encoded_body = encode_json(body);
        self.send_signed(identity, Method::DELETE, path, encoded_body)
            .await
    }

    async fn dispatch(&self, request: Request<Body>) -> TestResponse {
        let response = self
            .router
            .clone()
            .oneshot(request)
            .await
            .expect("the router never fails");
        let status = response.status();
        let body = to_bytes(response.into_body(), RESPONSE_BODY_LIMIT)
            .await
            .expect("the response body is readable");
        TestResponse {
            status,
            body: body.to_vec(),
        }
    }
}

pub fn sign_headers(
    identity: &DeviceIdentity,
    method: &Method,
    path: &str,
    body: &[u8],
    timestamp: DateTime<Utc>,
) -> RequestHeaderValues {
    let request_signature =
        sign_request(identity, method.as_str(), path, timestamp, body)
            .expect("the random source works");
    request_signature.to_header_values()
}

pub fn encode_json<Value: Serialize>(value: &Value) -> Vec<u8> {
    serde_json::to_vec(value).expect("test values encode as JSON")
}

pub fn block_on<Work: Future>(work: Work) -> Work::Output {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("the test runtime starts");
    runtime.block_on(work)
}

fn open_server(
    directory: &TempDir,
    clock: &Arc<ManualClock>,
    long_poll_timeout: Duration,
) -> SharedServer {
    let settings = ServerSettings {
        data_directory: directory.path().to_path_buf(),
        public_address: TEST_PUBLIC_ADDRESS.to_owned(),
        long_poll_timeout,
    };
    let shared_clock: Arc<dyn Clock> = Arc::clone(clock) as Arc<dyn Clock>;
    let server = Server::open(settings, shared_clock)
        .expect("the server opens its data directory");
    Arc::new(server)
}

fn build_request(
    method: Method,
    path: &str,
    body: Vec<u8>,
    header_values: Option<&RequestHeaderValues>,
) -> Request<Body> {
    let mut request = Request::builder()
        .method(method)
        .uri(path)
        .header("content-type", "application/json")
        .body(Body::from(body))
        .expect("the test request is well formed");
    if let Some(header_values) = header_values {
        let headers = request.headers_mut();
        headers.insert(DEVICE_HEADER, header_value(&header_values.device_id));
        headers
            .insert(TIMESTAMP_HEADER, header_value(&header_values.timestamp));
        headers
            .insert(SIGNATURE_HEADER, header_value(&header_values.signature));
        headers.insert(NONCE_HEADER, header_value(&header_values.nonce));
    }
    request
}

fn header_value(text: &str) -> HeaderValue {
    HeaderValue::from_str(text).expect("header text is visible ASCII")
}

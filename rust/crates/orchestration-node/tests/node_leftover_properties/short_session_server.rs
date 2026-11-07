use std::fs;
use std::future::IntoFuture;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use axum::body::{Body, to_bytes};
use axum::extract::{Request, State};
use axum::http::header::CONTENT_LENGTH;
use axum::http::{Method, StatusCode};
use axum::middleware::{Next, from_fn_with_state};
use axum::response::{IntoResponse, Response};
use chrono::{DateTime, TimeDelta, Utc};
use orchestration_api::routes::PAIRING_SESSIONS;
use orchestration_server::{
    Clock, Server, ServerSettings, SystemClock, build_router,
};
use serde_json::{Value, json};
use tempfile::TempDir;
use tokio::net::TcpListener;
use tokio::runtime::Runtime;

use crate::command_device::CommandDevice;
use crate::support::test_device::describe;

pub const SHORT_SESSION_LIFETIME: Duration = Duration::from_millis(500);
pub const SESSION_LIFETIMES: [SessionLifetime; 2] =
    [SessionLifetime::Short, SessionLifetime::Normal];
const LOOPBACK_ADDRESS: &str = "127.0.0.1:0";
const ADDRESS_SCHEME: &str = "http://";
const LONG_POLL_TIMEOUT: Duration = Duration::from_millis(50);
const BODY_LIMIT: usize = 16 * 1024 * 1024;
const SETUP_CODE_FILE_NAME: &str = "setup-code";
const STARTED_AT_FIELD: &str = "started_at";
const EXPIRES_AT_FIELD: &str = "expires_at";

type ShorteningSwitch = Arc<AtomicBool>;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SessionLifetime {
    Short,
    Normal,
}

#[derive(Debug)]
pub struct ShortSessionServer {
    pub address: String,
    shortening: ShorteningSwitch,
    _serving_runtime: Runtime,
    data_directory: TempDir,
}

impl ShortSessionServer {
    pub fn start() -> Result<Self, String> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(describe)?;
        let listener = runtime
            .block_on(TcpListener::bind(LOOPBACK_ADDRESS))
            .map_err(describe)?;
        let local_address = listener.local_addr().map_err(describe)?;
        let address = format!("{ADDRESS_SCHEME}{local_address}");
        let data_directory = TempDir::new().map_err(describe)?;

        let settings = ServerSettings {
            data_directory: data_directory.path().to_path_buf(),
            public_address: address.clone(),
            long_poll_timeout: LONG_POLL_TIMEOUT,
        };
        let clock: Arc<dyn Clock> = Arc::new(SystemClock);
        let server = Server::open(settings, clock).map_err(describe)?;
        let shortening = ShorteningSwitch::default();
        let middleware =
            from_fn_with_state(Arc::clone(&shortening), shorten_sessions);
        let router = build_router(Arc::new(server)).layer(middleware);
        runtime.spawn(axum::serve(listener, router).into_future());
        Ok(Self {
            address,
            shortening,
            _serving_runtime: runtime,
            data_directory,
        })
    }

    pub fn start_pairing_lasting(
        &self,
        approver: &dyn CommandDevice,
        lifetime: SessionLifetime,
    ) -> Result<Value, String> {
        let is_short = lifetime == SessionLifetime::Short;
        self.shortening.store(is_short, Ordering::SeqCst);
        let session = approver.run(&json!({ "command": "start_pairing" }));
        self.shortening.store(false, Ordering::SeqCst);
        session
    }

    pub fn build_create_account_command(&self) -> Result<Value, String> {
        let setup_code_path =
            self.data_directory.path().join(SETUP_CODE_FILE_NAME);
        let setup_code =
            fs::read_to_string(setup_code_path).map_err(describe)?;
        Ok(json!({
            "command": "create_account",
            "server_address": self.address,
            "setup_code": setup_code.trim(),
            "device_name": "air-laptop",
            "role": "client_and_runner",
            "workspace_name": "acme",
        }))
    }
}

async fn shorten_sessions(
    State(shortening): State<ShorteningSwitch>,
    request: Request,
    next: Next,
) -> Response {
    let is_session_start = request.method() == Method::POST
        && request.uri().path() == PAIRING_SESSIONS;
    let response = next.run(request).await;
    if !is_session_start || !shortening.load(Ordering::SeqCst) {
        return response;
    }
    rewrite_expiry(response).await
}

async fn rewrite_expiry(response: Response) -> Response {
    let (mut parts, body) = response.into_parts();
    let Ok(body_bytes) = to_bytes(body, BODY_LIMIT).await else {
        return StatusCode::BAD_GATEWAY.into_response();
    };
    let Ok(mut session) = serde_json::from_slice::<Value>(&body_bytes) else {
        return Response::from_parts(parts, Body::from(body_bytes));
    };
    let started_at = session[STARTED_AT_FIELD].as_str().unwrap_or_default();
    let Ok(started_at) = DateTime::parse_from_rfc3339(started_at) else {
        return Response::from_parts(parts, Body::from(body_bytes));
    };
    let lifetime =
        TimeDelta::from_std(SHORT_SESSION_LIFETIME).unwrap_or_default();
    let expires_at = started_at.with_timezone(&Utc) + lifetime;
    session[EXPIRES_AT_FIELD] = json!(expires_at);
    parts.headers.remove(CONTENT_LENGTH);
    Response::from_parts(parts, Body::from(session.to_string()))
}

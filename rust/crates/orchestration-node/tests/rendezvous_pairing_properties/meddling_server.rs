use std::fs;
use std::future::IntoFuture;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::time::Duration;

use axum::body::{Body, Bytes, to_bytes};
use axum::extract::{Request, State};
use axum::http::header::CONTENT_LENGTH;
use axum::http::{Method, StatusCode};
use axum::middleware::{Next, from_fn_with_state};
use axum::response::{IntoResponse, Response};
use orchestration_server::{
    Clock, Server, ServerSettings, SystemClock, build_router,
};
use serde_json::{Value, json};
use tempfile::TempDir;
use tokio::net::TcpListener;
use tokio::runtime::Runtime;

use crate::support::test_device::describe;

const LOOPBACK_ADDRESS: &str = "127.0.0.1:0";
const ADDRESS_SCHEME: &str = "http://";
const LONG_POLL_TIMEOUT: Duration = Duration::from_millis(50);
const BODY_LIMIT: usize = 16 * 1024 * 1024;
const SETUP_CODE_FILE_NAME: &str = "setup-code";
const SESSIONS_PREFIX: &str = "/pairing/sessions/";
const NONCE_SUFFIX: &str = "/nonce";
const ENDING_SUFFIXES: [&str; 3] = ["/cancel", "/reject", "/approve"];
const PATH_SEPARATOR: char = '/';
pub const REFUSED_ENDING_MESSAGE: &str = "the ending was refused on purpose";
const FOREIGN_BYTE: u8 = 7;
const FOREIGN_BYTE_COUNT: usize = 32;
const BYTE_VALUES: u64 = 256;

type SharedMeddling = Arc<Mutex<Meddling>>;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum EndingAnswer {
    Forwarded,
    Swallowed,
    Refused,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum JoiningRewrite {
    SigningKey,
    SealingKey,
    JoinerNonce,
    ApproverNonce,
    HiddenJoinerNonce,
}

#[derive(Debug)]
struct Meddling {
    ending_answer: EndingAnswer,
    joining_rewrite: Option<JoiningRewrite>,
    revealed_nonces: Vec<Value>,
}

#[derive(Debug)]
pub struct MeddlingServer {
    pub address: String,
    meddling: SharedMeddling,
    _serving_runtime: Runtime,
    data_directory: TempDir,
}

impl JoiningRewrite {
    fn field_name(self) -> &'static str {
        match self {
            Self::SigningKey => "signing_public_key",
            Self::SealingKey => "sealing_public_key",
            Self::JoinerNonce | Self::HiddenJoinerNonce => "joiner_nonce",
            Self::ApproverNonce => "approver_nonce",
        }
    }

    fn rewrite(self, shown_bytes: &Value) -> Value {
        if self == Self::HiddenJoinerNonce {
            return Value::Null;
        }
        let Some(bytes) = shown_bytes.as_array() else {
            return json!(vec![FOREIGN_BYTE; FOREIGN_BYTE_COUNT]);
        };
        let mut changed_bytes = bytes.clone();
        if let Some(first_byte) = changed_bytes.first_mut() {
            let first_value = first_byte.as_u64().unwrap_or_default();
            *first_byte = json!((first_value + 1) % BYTE_VALUES);
        }
        Value::Array(changed_bytes)
    }
}

impl MeddlingServer {
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
        let meddling = Arc::new(Mutex::new(Meddling {
            ending_answer: EndingAnswer::Forwarded,
            joining_rewrite: None,
            revealed_nonces: Vec::new(),
        }));
        let middleware =
            from_fn_with_state(Arc::clone(&meddling), meddle_with_pairing);
        let router = build_router(Arc::new(server)).layer(middleware);
        runtime.spawn(axum::serve(listener, router).into_future());
        Ok(Self {
            address,
            meddling,
            _serving_runtime: runtime,
            data_directory,
        })
    }

    pub fn answer_endings(&self, ending_answer: EndingAnswer) {
        lock_meddling(&self.meddling).ending_answer = ending_answer;
    }

    pub fn rewrite_joining(&self, joining_rewrite: Option<JoiningRewrite>) {
        lock_meddling(&self.meddling).joining_rewrite = joining_rewrite;
    }

    pub fn list_revealed_nonces(&self) -> Vec<Value> {
        lock_meddling(&self.meddling).revealed_nonces.clone()
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

async fn meddle_with_pairing(
    State(meddling): State<SharedMeddling>,
    request: Request,
    next: Next,
) -> Response {
    let path = request.uri().path().to_owned();
    let Some(session_route) = path.strip_prefix(SESSIONS_PREFIX) else {
        return next.run(request).await;
    };
    let method = request.method().clone();
    let is_ending = ENDING_SUFFIXES
        .iter()
        .any(|suffix| session_route.ends_with(suffix));
    if method == Method::POST && is_ending {
        let ending_answer = lock_meddling(&meddling).ending_answer;
        return answer_ending(ending_answer, request, next).await;
    }
    if method == Method::POST && session_route.ends_with(NONCE_SUFFIX) {
        return record_revealed_nonce(&meddling, request, next).await;
    }
    let is_session_view = !session_route.contains(PATH_SEPARATOR);
    let joining_rewrite = lock_meddling(&meddling).joining_rewrite;
    let response = next.run(request).await;
    match joining_rewrite {
        Some(rewrite) if method == Method::GET && is_session_view => {
            rewrite_session_view(response, rewrite).await
        }
        _ => response,
    }
}

async fn answer_ending(
    ending_answer: EndingAnswer,
    request: Request,
    next: Next,
) -> Response {
    match ending_answer {
        EndingAnswer::Forwarded => next.run(request).await,
        EndingAnswer::Swallowed => StatusCode::NO_CONTENT.into_response(),
        EndingAnswer::Refused => {
            (StatusCode::CONFLICT, REFUSED_ENDING_MESSAGE).into_response()
        }
    }
}

async fn record_revealed_nonce(
    meddling: &SharedMeddling,
    request: Request,
    next: Next,
) -> Response {
    let (parts, body) = request.into_parts();
    let Ok(body_bytes) = to_bytes(body, BODY_LIMIT).await else {
        return StatusCode::BAD_REQUEST.into_response();
    };
    let revealed: Value =
        serde_json::from_slice(&body_bytes).unwrap_or_default();
    lock_meddling(meddling)
        .revealed_nonces
        .push(revealed["nonce"].clone());
    let forwarded = Request::from_parts(parts, Body::from(body_bytes));
    next.run(forwarded).await
}

async fn rewrite_session_view(
    response: Response,
    rewrite: JoiningRewrite,
) -> Response {
    let (mut parts, body) = response.into_parts();
    let Ok(body_bytes) = to_bytes(body, BODY_LIMIT).await else {
        return StatusCode::BAD_GATEWAY.into_response();
    };
    let Ok(mut view) = serde_json::from_slice::<Value>(&body_bytes) else {
        return Response::from_parts(parts, Body::from(body_bytes));
    };
    let field_pointer = format!("/joining/{}", rewrite.field_name());
    if let Some(shown_field) = view.pointer_mut(&field_pointer) {
        *shown_field = rewrite.rewrite(shown_field);
    }
    let rewritten_bytes = Bytes::from(view.to_string());
    parts.headers.remove(CONTENT_LENGTH);
    Response::from_parts(parts, Body::from(rewritten_bytes))
}

fn lock_meddling(meddling: &SharedMeddling) -> MutexGuard<'_, Meddling> {
    meddling.lock().unwrap_or_else(PoisonError::into_inner)
}

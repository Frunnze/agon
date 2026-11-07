use std::future::IntoFuture;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use axum::Router;
use axum::extract::State;
use axum::http::{Method, StatusCode, Uri};
use orchestration_p2p::board_retry::BOARD_RETRY_PAUSES;
use orchestration_p2p::record_board::PUBLIC_RECORD_BOARD;
use serde_json::{Value, json};
use tempfile::TempDir;
use tokio::net::TcpListener;
use tokio::runtime::Runtime;
use url::Url;

use crate::command_device::CommandDevice;
use crate::support::node_process::{NodeProcess, ProcessSetup};
use crate::support::test_device::describe;

const LOOPBACK_ADDRESS: &str = "127.0.0.1:0";
const ADDRESS_SCHEME: &str = "http://";
const LOCAL_RELAY_ADDRESS: &str = "http://127.0.0.1:9";
const UNPROXIED_HOST: &str = "127.0.0.1";
const PROXY_CANARY_SERVER: &str = "http://localhost:9";
const PROXY_CANARY_LINE: &str = "http://localhost:9/";
const CONNECT_METHOD: &str = "CONNECT";
const PROXY_VARIABLES: [&str; 6] = [
    "HTTPS_PROXY",
    "https_proxy",
    "HTTP_PROXY",
    "http_proxy",
    "ALL_PROXY",
    "all_proxy",
];
const BYPASS_VARIABLES: [&str; 2] = ["NO_PROXY", "no_proxy"];

type RequestLines = Arc<Mutex<Vec<String>>>;

#[derive(Debug)]
pub struct RefusingProxy {
    pub address: String,
    request_lines: RequestLines,
    _serving_runtime: Runtime,
}

#[derive(Debug)]
pub struct ProxiedDevice {
    process: NodeProcess,
    _data_directory: TempDir,
}

impl RefusingProxy {
    pub fn start() -> Result<Self, String> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(describe)?;
        let listener = runtime
            .block_on(TcpListener::bind(LOOPBACK_ADDRESS))
            .map_err(describe)?;
        let local_address = listener.local_addr().map_err(describe)?;
        let request_lines = RequestLines::default();
        let router = Router::new()
            .fallback(record_and_refuse)
            .with_state(Arc::clone(&request_lines));
        runtime.spawn(axum::serve(listener, router).into_future());
        Ok(Self {
            address: format!("{ADDRESS_SCHEME}{local_address}"),
            request_lines,
            _serving_runtime: runtime,
        })
    }

    pub fn count_board_attempts(&self) -> Result<usize, String> {
        let board_line = describe_board_tunnel()?;
        let request_lines = lock_request_lines(&self.request_lines);
        let mut attempt_count = 0;
        for request_line in request_lines.iter() {
            if *request_line == board_line {
                attempt_count += 1;
            }
        }
        Ok(attempt_count)
    }

    fn has_seen(&self, expected_line: &str) -> bool {
        let request_lines = lock_request_lines(&self.request_lines);
        request_lines
            .iter()
            .any(|line| line.contains(expected_line))
    }
}

impl ProxiedDevice {
    pub fn start(proxy: &RefusingProxy) -> Result<Self, String> {
        let data_directory = TempDir::new().map_err(describe)?;
        let configuration = json!({
            "data_directory": data_directory.path(),
            "identity_store": "file",
            "peer_relay": { "custom": LOCAL_RELAY_ADDRESS },
            "runner": "off",
        });
        let mut environment = Vec::new();
        for variable in PROXY_VARIABLES {
            environment.push((variable, proxy.address.clone()));
        }
        for variable in BYPASS_VARIABLES {
            environment.push((variable, UNPROXIED_HOST.to_owned()));
        }
        let process = NodeProcess::start(&ProcessSetup {
            configuration: &configuration,
            environment: &environment,
        })?;
        let device = Self {
            process,
            _data_directory: data_directory,
        };
        device.confirm_proxy_use(proxy)?;
        Ok(device)
    }

    fn confirm_proxy_use(&self, proxy: &RefusingProxy) -> Result<(), String> {
        let canary_account = self.process.run(&json!({
            "command": "create_account",
            "server_address": PROXY_CANARY_SERVER,
            "setup_code": "000000",
            "device_name": "air-laptop",
            "role": "client_and_runner",
            "workspace_name": "acme",
        }));
        if canary_account.is_ok() || !proxy.has_seen(PROXY_CANARY_LINE) {
            return Err(format!(
                "the node ignores the proxy, so the board stays untouched: \
                 {canary_account:?}"
            ));
        }
        Ok(())
    }
}

impl CommandDevice for ProxiedDevice {
    fn run(&self, command: &Value) -> Result<Value, String> {
        self.process.run(command)
    }
}

pub fn count_attempts_per_publish() -> usize {
    BOARD_RETRY_PAUSES.len() + 1
}

fn describe_board_tunnel() -> Result<String, String> {
    let board_address = Url::parse(PUBLIC_RECORD_BOARD).map_err(describe)?;
    let board_host =
        board_address.host_str().ok_or("the board has no host")?;
    let board_port = board_address
        .port_or_known_default()
        .ok_or("the board has no port")?;
    Ok(format!("{CONNECT_METHOD} {board_host}:{board_port}"))
}

async fn record_and_refuse(
    State(request_lines): State<RequestLines>,
    method: Method,
    uri: Uri,
) -> StatusCode {
    lock_request_lines(&request_lines).push(format!("{method} {uri}"));
    StatusCode::FORBIDDEN
}

fn lock_request_lines(
    request_lines: &RequestLines,
) -> MutexGuard<'_, Vec<String>> {
    request_lines.lock().unwrap_or_else(PoisonError::into_inner)
}

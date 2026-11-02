use std::fs;
use std::future::IntoFuture;
use std::net::TcpListener as StandardTcpListener;
use std::path::Path;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use axum::Router;
use axum::body::{Body, to_bytes};
use axum::extract::{Request, State};
use axum::middleware::{Next, from_fn_with_state};
use axum::response::Response;
use orchestration_server::{
    Clock, Server, ServerSettings, SystemClock, build_router,
};
use tempfile::TempDir;
use tokio::sync::oneshot;

use super::test_device::describe;

const LOOPBACK_ADDRESS: &str = "127.0.0.1:0";
const ADDRESS_SCHEME: &str = "http://";
const REQUEST_BODY_LIMIT: usize = 16 * 1024 * 1024;
const LONG_POLL_TIMEOUT: Duration = Duration::from_millis(50);
const SETUP_CODE_FILE_NAME: &str = "setup-code";

#[derive(Clone, Debug)]
pub struct RecordedRequest {
    pub method: String,
    pub path: String,
    pub body: Vec<u8>,
    pub status: u16,
}

type Recording = Arc<Mutex<Vec<RecordedRequest>>>;

#[derive(Debug)]
struct ServingThread {
    shutdown: oneshot::Sender<()>,
    thread: JoinHandle<()>,
}

#[derive(Debug)]
pub struct TestServer {
    pub address: String,
    recording: Recording,
    data_directory: TempDir,
    serving: Mutex<Option<ServingThread>>,
}

impl TestServer {
    pub fn start() -> Result<Self, String> {
        let listener = bind_listener(LOOPBACK_ADDRESS)?;
        let local_address = listener.local_addr().map_err(describe)?;
        let address = format!("{ADDRESS_SCHEME}{local_address}");
        let data_directory = TempDir::new().map_err(describe)?;
        let recording = Recording::default();
        let serving = TestServer::serve(
            listener,
            &address,
            data_directory.path(),
            &recording,
        )?;
        Ok(Self {
            address,
            recording,
            data_directory,
            serving: Mutex::new(Some(serving)),
        })
    }

    pub fn is_running(&self) -> bool {
        self.lock_serving().is_some()
    }

    pub fn stop(&self) -> Result<(), String> {
        let serving = self
            .lock_serving()
            .take()
            .ok_or("the test server is not running")?;
        serving
            .shutdown
            .send(())
            .map_err(|()| "the test server had already stopped")?;
        serving
            .thread
            .join()
            .map_err(|_| "the test server thread panicked".to_owned())
    }

    pub fn start_again(&self) -> Result<(), String> {
        let mut serving = self.lock_serving();
        if serving.is_some() {
            return Err("the test server is already running".to_owned());
        }
        let listen_address = self.address.trim_start_matches(ADDRESS_SCHEME);
        let listener = bind_listener(listen_address)?;
        *serving = Some(TestServer::serve(
            listener,
            &self.address,
            self.data_directory.path(),
            &self.recording,
        )?);
        Ok(())
    }

    fn serve(
        listener: StandardTcpListener,
        address: &str,
        data_directory: &Path,
        recording: &Recording,
    ) -> Result<ServingThread, String> {
        let settings = ServerSettings {
            data_directory: data_directory.to_path_buf(),
            public_address: address.to_owned(),
            long_poll_timeout: LONG_POLL_TIMEOUT,
        };
        let clock: Arc<dyn Clock> = Arc::new(SystemClock);
        let server = Server::open(settings, clock).map_err(describe)?;
        let router = build_router(Arc::new(server))
            .layer(from_fn_with_state(Arc::clone(recording), record_request));
        let (shutdown, shutdown_signal) = oneshot::channel();
        let thread = thread::spawn(move || {
            serve_until_stopped(listener, router, shutdown_signal);
        });
        Ok(ServingThread { shutdown, thread })
    }

    fn lock_serving(&self) -> MutexGuard<'_, Option<ServingThread>> {
        self.serving.lock().unwrap_or_else(PoisonError::into_inner)
    }

    pub fn recorded_requests(&self) -> Vec<RecordedRequest> {
        lock_recording(&self.recording).clone()
    }

    pub fn read_setup_code(&self) -> Result<String, String> {
        let setup_code_path =
            self.data_directory.path().join(SETUP_CODE_FILE_NAME);
        let setup_code =
            fs::read_to_string(setup_code_path).map_err(describe)?;
        Ok(setup_code.trim().to_owned())
    }

    pub fn read_stored_state(&self) -> Result<String, String> {
        let mut stored_text = String::new();
        for entry in
            fs::read_dir(self.data_directory.path()).map_err(describe)?
        {
            let entry_path = entry.map_err(describe)?.path();
            if entry_path.is_file() {
                let stored_bytes = fs::read(entry_path).map_err(describe)?;
                stored_text.push_str(&String::from_utf8_lossy(&stored_bytes));
            }
        }
        Ok(stored_text)
    }
}

fn lock_recording(
    recording: &Recording,
) -> MutexGuard<'_, Vec<RecordedRequest>> {
    recording.lock().unwrap_or_else(PoisonError::into_inner)
}

fn bind_listener(listen_address: &str) -> Result<StandardTcpListener, String> {
    let listener =
        StandardTcpListener::bind(listen_address).map_err(describe)?;
    listener.set_nonblocking(true).map_err(describe)?;
    Ok(listener)
}

fn serve_until_stopped(
    listener: StandardTcpListener,
    router: Router,
    shutdown_signal: oneshot::Receiver<()>,
) {
    let Ok(runtime) = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    else {
        return;
    };
    runtime.block_on(async move {
        let Ok(listener) = tokio::net::TcpListener::from_std(listener) else {
            return;
        };
        let serving = axum::serve(listener, router).into_future();
        tokio::select! {
            served = serving => {
                if let Err(error) = served {
                    eprintln!("the test server stopped: {error}");
                }
            }
            Ok(()) = shutdown_signal => {}
        }
    });
}

async fn record_request(
    State(recording): State<Recording>,
    request: Request,
    next: Next,
) -> Response {
    let (parts, body) = request.into_parts();
    let body_bytes =
        to_bytes(body, REQUEST_BODY_LIMIT).await.unwrap_or_default();
    let method = parts.method.to_string();
    let path = parts
        .uri
        .path_and_query()
        .map_or_else(String::new, ToString::to_string);

    let forwarded = Request::from_parts(parts, Body::from(body_bytes.clone()));
    let response = next.run(forwarded).await;

    lock_recording(&recording).push(RecordedRequest {
        method,
        path,
        body: body_bytes.to_vec(),
        status: response.status().as_u16(),
    });
    response
}

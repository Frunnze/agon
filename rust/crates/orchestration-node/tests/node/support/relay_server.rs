use std::future::IntoFuture;
use std::net::TcpListener as StandardTcpListener;
use std::sync::Arc;
use std::thread::{self, JoinHandle};

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum::{Json, Router};
use orchestration_api::accounts::{
    JoinAccepted, JoinRequest, JoinStatus, PairingNonce,
};
use orchestration_api::routes::{
    PAIRING_JOIN, PAIRING_JOIN_STATUS, PAIRING_JOINER_NONCE,
};
use orchestration_node::server_address::ServerAddress;
use orchestration_node::server_client::{PeerDialer, ServerClient};
use orchestration_p2p::peer_configuration::RelayChoice;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::pairing::{
    PairingCode, PairingPublicKeys, commit_to_approver_nonce,
    generate_pairing_nonce,
};
use tokio::sync::oneshot;
use uuid::Uuid;

use super::test_device::describe;

const LOOPBACK_ADDRESS: &str = "127.0.0.1:0";
const ADDRESS_SCHEME: &str = "http://";

type RelayAnswer<Answer> = Result<Answer, (StatusCode, String)>;
type SharedRelay = Arc<RelayState>;

#[derive(Debug)]
struct RelayState {
    real_server: ServerClient,
    relay_keys: PairingPublicKeys,
    nonce_toward_joiner: Vec<u8>,
    nonce_toward_approver: Vec<u8>,
}

#[derive(Debug)]
pub struct RelayServer {
    pub address: String,
    shutdown: Option<oneshot::Sender<()>>,
    thread: Option<JoinHandle<()>>,
}

impl RelayServer {
    pub fn start(real_server_address: &str) -> Result<Self, String> {
        let listener =
            StandardTcpListener::bind(LOOPBACK_ADDRESS).map_err(describe)?;
        listener.set_nonblocking(true).map_err(describe)?;
        let local_address = listener.local_addr().map_err(describe)?;
        let real_address =
            ServerAddress::parse(real_server_address).map_err(describe)?;
        let dialer = Arc::new(PeerDialer::new(RelayChoice::Disabled));
        let relay_identity = DeviceIdentity::generate().map_err(describe)?;
        let relay = RelayState {
            real_server: ServerClient::connect(&real_address, &dialer)
                .map_err(describe)?,
            relay_keys: PairingPublicKeys::of_identity(&relay_identity),
            nonce_toward_joiner: generate_pairing_nonce().map_err(describe)?,
            nonce_toward_approver: generate_pairing_nonce()
                .map_err(describe)?,
        };

        let router = Router::new()
            .route(PAIRING_JOIN, post(relay_join))
            .route(PAIRING_JOINER_NONCE, post(relay_joiner_nonce))
            .route(PAIRING_JOIN_STATUS, get(relay_join_status))
            .with_state(Arc::new(relay));
        let (shutdown, shutdown_signal) = oneshot::channel();
        let thread = thread::spawn(move || {
            serve_relay(listener, router, shutdown_signal);
        });
        Ok(Self {
            address: format!("{ADDRESS_SCHEME}{local_address}"),
            shutdown: Some(shutdown),
            thread: Some(thread),
        })
    }
}

impl Drop for RelayServer {
    fn drop(&mut self) {
        if let Some(shutdown) = self.shutdown.take() {
            let _already_stopped = shutdown.send(());
        }
        if let Some(thread) = self.thread.take() {
            let _finished = thread.join();
        }
    }
}

async fn relay_join(
    State(relay): State<SharedRelay>,
    Json(joiner_request): Json<JoinRequest>,
) -> RelayAnswer<(StatusCode, Json<JoinAccepted>)> {
    let code = PairingCode::parse(&joiner_request.code).map_err(refuse)?;
    let mut substituted_device = joiner_request.device;
    substituted_device.signing_public_key =
        relay.relay_keys.signing_public_key.clone();
    substituted_device.sealing_public_key =
        relay.relay_keys.sealing_public_key.clone();
    let substituted_request = JoinRequest {
        code: joiner_request.code,
        device: substituted_device,
    };

    let real_accepted = relay
        .real_server
        .join_with_code(&substituted_request)
        .await
        .map_err(refuse)?;
    let relay_commitment = commit_to_approver_nonce(
        &code,
        &relay.relay_keys,
        &relay.nonce_toward_joiner,
    );
    let offered = JoinAccepted {
        join_id: real_accepted.join_id,
        approver_signing_public_key: relay
            .relay_keys
            .signing_public_key
            .clone(),
        approver_sealing_public_key: relay
            .relay_keys
            .sealing_public_key
            .clone(),
        approver_commitment: relay_commitment,
    };
    Ok((StatusCode::CREATED, Json(offered)))
}

async fn relay_joiner_nonce(
    State(relay): State<SharedRelay>,
    Path(join_id): Path<Uuid>,
) -> RelayAnswer<StatusCode> {
    let relay_nonce = PairingNonce {
        nonce: relay.nonce_toward_approver.clone(),
    };
    relay
        .real_server
        .send_joiner_nonce(join_id, &relay_nonce)
        .await
        .map_err(refuse)?;
    Ok(StatusCode::NO_CONTENT)
}

async fn relay_join_status(
    State(relay): State<SharedRelay>,
    Path(join_id): Path<Uuid>,
) -> RelayAnswer<Json<JoinStatus>> {
    let real_status = relay
        .real_server
        .read_join_status(join_id)
        .await
        .map_err(refuse)?;
    let shown_status = match real_status {
        JoinStatus::Waiting {
            approver_nonce: Some(_),
        } => JoinStatus::Waiting {
            approver_nonce: Some(relay.nonce_toward_joiner.clone()),
        },
        JoinStatus::Approved { account, .. } => JoinStatus::Approved {
            account,
            approver_nonce: relay.nonce_toward_joiner.clone(),
        },
        other_status => other_status,
    };
    Ok(Json(shown_status))
}

fn refuse(problem: impl std::fmt::Display) -> (StatusCode, String) {
    (StatusCode::BAD_GATEWAY, problem.to_string())
}

fn serve_relay(
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
                    eprintln!("the relay server stopped: {error}");
                }
            }
            Ok(()) = shutdown_signal => {}
        }
    });
}

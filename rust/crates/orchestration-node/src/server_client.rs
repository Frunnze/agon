mod account_routes;
mod catalog_routes;
mod deletion_routes;
mod group_routes;
mod outgoing_request;
mod peer_dialer;
mod peer_link_route;
mod person_step_routes;
mod protected_files_routes;
mod route_paths;
mod runner_routes;
mod signed_server_client;
mod web_route;
mod work_routes;

use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};

use chrono::Utc;
use orchestration_api::accounts::{
    JoinAccepted, JoinRequest, JoinStatus, PairingNonce,
};
use orchestration_api::routes::{
    DEVICE_HEADER, HEALTH, NONCE_HEADER, PAIRING_JOIN, PAIRING_JOIN_STATUS,
    PAIRING_JOINER_NONCE, SIGNATURE_HEADER, TIMESTAMP_HEADER,
};
use orchestration_api::updates::ApiErrorBody;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::request_signing::sign_request;
use reqwest::{Method, StatusCode};
use serde::de::DeserializeOwned;
use uuid::Uuid;

use crate::node_error::NodeError;
use crate::server_address::ServerAddress;
use outgoing_request::OutgoingRequest;
use peer_link_route::PeerLinkRoute;
use web_route::WebRoute;

pub use peer_dialer::PeerDialer;
pub use route_paths::{encode_path_segment, fill_route};
pub use signed_server_client::SignedServerClient;

#[derive(Clone, Debug)]
pub struct ServerClient {
    address: ServerAddress,
    routes: Arc<Vec<ServerRoute>>,
    preferred_route: Arc<AtomicUsize>,
}

#[derive(Clone, Debug)]
enum ServerRoute {
    Web(WebRoute),
    PeerLink(Arc<PeerLinkRoute>),
}

#[derive(Debug)]
struct ServerAnswer {
    status: u16,
    body: Vec<u8>,
}

impl ServerClient {
    pub fn connect(
        address: &ServerAddress,
        dialer: &Arc<PeerDialer>,
    ) -> Result<Self, NodeError> {
        Self::connect_in_order(address, std::slice::from_ref(address), dialer)
    }

    pub fn connect_in_order(
        address: &ServerAddress,
        ordered_addresses: &[ServerAddress],
        dialer: &Arc<PeerDialer>,
    ) -> Result<Self, NodeError> {
        if ordered_addresses.is_empty() {
            return Err(NodeError::NoAppServer);
        }
        let mut routes = Vec::new();
        for ordered_address in ordered_addresses {
            routes.push(open_route(ordered_address, dialer)?);
        }
        Ok(Self {
            address: address.clone(),
            routes: Arc::new(routes),
            preferred_route: Arc::default(),
        })
    }

    #[must_use]
    pub fn address(&self) -> &ServerAddress {
        &self.address
    }

    #[must_use]
    pub fn signed<'client>(
        &'client self,
        identity: &'client DeviceIdentity,
    ) -> SignedServerClient<'client> {
        SignedServerClient::new(self, identity)
    }

    pub async fn check_health(&self) -> Result<(), NodeError> {
        let request = OutgoingRequest::without_body(Method::GET, HEALTH);
        self.send_unsigned(request).await?;
        Ok(())
    }

    pub async fn join_with_code(
        &self,
        join_request: &JoinRequest,
    ) -> Result<JoinAccepted, NodeError> {
        let request = OutgoingRequest::with_json_body(
            Method::POST,
            PAIRING_JOIN,
            join_request,
        )?;
        let answer = self.send_unsigned(request).await?;
        decode_answer(&answer)
    }

    pub async fn send_joiner_nonce(
        &self,
        join_id: Uuid,
        nonce: &PairingNonce,
    ) -> Result<(), NodeError> {
        let join_text = join_id.to_string();
        let path =
            fill_route(PAIRING_JOINER_NONCE, &[("join_id", &join_text)])?;
        let request =
            OutgoingRequest::with_json_body(Method::POST, &path, nonce)?;
        self.send_unsigned(request).await?;
        Ok(())
    }

    pub async fn read_join_status(
        &self,
        join_id: Uuid,
    ) -> Result<JoinStatus, NodeError> {
        let join_text = join_id.to_string();
        let path =
            fill_route(PAIRING_JOIN_STATUS, &[("join_id", &join_text)])?;
        let request = OutgoingRequest::without_body(Method::GET, &path);
        let answer = self.send_unsigned(request).await?;
        decode_answer(&answer)
    }

    async fn send_unsigned(
        &self,
        request: OutgoingRequest,
    ) -> Result<Vec<u8>, NodeError> {
        let answer = self.deliver(request).await?;
        accept_answer(answer)
    }

    async fn send_signed(
        &self,
        identity: &DeviceIdentity,
        request: OutgoingRequest,
    ) -> Result<Vec<u8>, NodeError> {
        let request_signature = sign_request(
            identity,
            request.method.as_str(),
            &request.path,
            Utc::now(),
            &request.body,
        )?;
        let header_values = request_signature.to_header_values();
        let signed_request = request.with_headers(vec![
            (DEVICE_HEADER, header_values.device_id),
            (TIMESTAMP_HEADER, header_values.timestamp),
            (NONCE_HEADER, header_values.nonce),
            (SIGNATURE_HEADER, header_values.signature),
        ]);
        let answer = self.deliver(signed_request).await?;
        accept_answer(answer)
    }

    async fn deliver(
        &self,
        request: OutgoingRequest,
    ) -> Result<ServerAnswer, NodeError> {
        let route_count = self.routes.len();
        let first_index = self.preferred_route.load(Ordering::Relaxed);
        let ordered_routes = self
            .routes
            .iter()
            .enumerate()
            .cycle()
            .skip(first_index)
            .take(route_count);
        let mut last_outcome = Err(NodeError::NoAppServer);
        for (index, route) in ordered_routes {
            let outcome = Box::pin(route.deliver(request.clone())).await;
            if !should_try_next_server(&outcome) {
                self.preferred_route.store(index, Ordering::Relaxed);
                return outcome;
            }
            last_outcome = outcome;
        }
        last_outcome
    }
}

impl ServerRoute {
    async fn deliver(
        &self,
        request: OutgoingRequest,
    ) -> Result<ServerAnswer, NodeError> {
        match self {
            Self::Web(route) => route.deliver(request).await,
            Self::PeerLink(route) => route.deliver(request).await,
        }
    }
}

fn open_route(
    address: &ServerAddress,
    dialer: &Arc<PeerDialer>,
) -> Result<ServerRoute, NodeError> {
    match address {
        ServerAddress::Web(web_address) => {
            Ok(ServerRoute::Web(WebRoute::open(web_address)?))
        }
        ServerAddress::Peer(peer_address) => {
            let route =
                PeerLinkRoute::new(peer_address.clone(), Arc::clone(dialer));
            Ok(ServerRoute::PeerLink(Arc::new(route)))
        }
    }
}

fn should_try_next_server(outcome: &Result<ServerAnswer, NodeError>) -> bool {
    match outcome {
        Ok(answer) => answer.status == StatusCode::MISDIRECTED_REQUEST,
        Err(NodeError::ServerUnreachable(_)) => true,
        Err(_) => false,
    }
}

fn accept_answer(answer: ServerAnswer) -> Result<Vec<u8>, NodeError> {
    let status = StatusCode::from_u16(answer.status)
        .map_err(|error| NodeError::UnexpectedAnswer(error.to_string()))?;
    if !status.is_success() {
        return Err(NodeError::ServerRejected {
            status: answer.status,
            message: read_error_message(&answer.body, status),
        });
    }
    Ok(answer.body)
}

fn read_error_message(answer: &[u8], status: StatusCode) -> String {
    if let Ok(error_body) = serde_json::from_slice::<ApiErrorBody>(answer) {
        return error_body.message;
    }
    let answer_text = String::from_utf8_lossy(answer).trim().to_owned();
    if !answer_text.is_empty() {
        return answer_text;
    }
    status.canonical_reason().unwrap_or_default().to_owned()
}

fn decode_answer<Answer: DeserializeOwned>(
    answer: &[u8],
) -> Result<Answer, NodeError> {
    serde_json::from_slice(answer)
        .map_err(|error| NodeError::UnexpectedAnswer(error.to_string()))
}

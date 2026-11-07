use std::sync::Arc;

use http_body_util::{BodyExt, Full};
use hyper::Request;
use hyper::body::Bytes;
use hyper::client::conn::http1;
use hyper_util::rt::TokioIo;
use orchestration_core::peer_address::PeerAddress;
use orchestration_p2p::peer_connection::PeerConnection;
use tokio::sync::Mutex;
use tokio::time::timeout;

use super::ServerAnswer;
use super::outgoing_request::OutgoingRequest;
use super::peer_dialer::PeerDialer;
use crate::node_error::NodeError;

const LATE_ANSWER: &str = "the app server did not answer in time";

type RequestBody = Full<Bytes>;

#[derive(Debug)]
pub(super) struct PeerLinkRoute {
    server: Mutex<PeerAddress>,
    dialer: Arc<PeerDialer>,
    connection: Mutex<Option<PeerConnection>>,
}

impl PeerLinkRoute {
    pub(super) fn new(server: PeerAddress, dialer: Arc<PeerDialer>) -> Self {
        Self {
            server: Mutex::new(server),
            dialer,
            connection: Mutex::new(None),
        }
    }

    pub(super) async fn deliver(
        &self,
        request: OutgoingRequest,
    ) -> Result<ServerAnswer, NodeError> {
        let answer = self.deliver_within_limit(request.clone()).await;
        if !matches!(answer, Err(NodeError::ServerUnreachable(_))) {
            return answer;
        }
        let known_server = self.server.lock().await.clone();
        let Some(moved_server) =
            self.dialer.find_moved_server(&known_server).await
        else {
            return answer;
        };
        *self.server.lock().await = moved_server;
        self.deliver_within_limit(request).await
    }

    async fn deliver_within_limit(
        &self,
        request: OutgoingRequest,
    ) -> Result<ServerAnswer, NodeError> {
        let answer_limit = request.timeout;
        let answer = timeout(answer_limit, self.exchange(request))
            .await
            .unwrap_or_else(|_| {
                Err(NodeError::ServerUnreachable(LATE_ANSWER.to_owned()))
            });
        if answer.is_err() {
            *self.connection.lock().await = None;
        }
        answer
    }

    async fn exchange(
        &self,
        request: OutgoingRequest,
    ) -> Result<ServerAnswer, NodeError> {
        let connection = self.reuse_or_connect().await?;
        let http_request = build_http_request(request)?;
        send_over_connection(&connection, http_request).await
    }

    async fn reuse_or_connect(&self) -> Result<PeerConnection, NodeError> {
        let mut cached = self.connection.lock().await;
        if let Some(connection) = cached.as_ref()
            && !connection.is_closed()
        {
            return Ok(connection.clone());
        }
        let server = self.server.lock().await.clone();
        let connection = self.dialer.connect(&server).await?;
        *cached = Some(connection.clone());
        Ok(connection)
    }
}

fn build_http_request(
    request: OutgoingRequest,
) -> Result<Request<RequestBody>, NodeError> {
    let mut builder =
        Request::builder().method(request.method).uri(&request.path);
    for (name, value) in request.headers {
        builder = builder.header(name, value);
    }
    builder
        .body(Full::new(Bytes::from(request.body)))
        .map_err(|_| NodeError::InvalidRouteValue(request.path))
}

async fn send_over_connection(
    connection: &PeerConnection,
    http_request: Request<RequestBody>,
) -> Result<ServerAnswer, NodeError> {
    let stream = connection.open_stream().await.map_err(|problem| {
        NodeError::ServerUnreachable(problem.to_string())
    })?;
    let (mut sender, link) = http1::handshake(TokioIo::new(stream))
        .await
        .map_err(|problem| describe_unreachable(&problem))?;

    let exchanging = async move {
        let response = sender
            .send_request(http_request)
            .await
            .map_err(|problem| describe_unreachable(&problem))?;
        let status = response.status().as_u16();
        let collected = response
            .into_body()
            .collect()
            .await
            .map_err(|problem| describe_unreachable(&problem))?;
        Ok(ServerAnswer {
            status,
            body: collected.to_bytes().to_vec(),
        })
    };
    let (answer, _link_ended) = tokio::join!(exchanging, link);
    answer
}

fn describe_unreachable(problem: &hyper::Error) -> NodeError {
    NodeError::ServerUnreachable(problem.to_string())
}

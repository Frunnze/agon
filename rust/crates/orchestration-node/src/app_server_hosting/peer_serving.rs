use std::sync::Arc;

use axum::Router;
use hyper::server::conn::http1;
use hyper_util::rt::TokioIo;
use hyper_util::service::TowerToHyperService;
use orchestration_p2p::peer_connection::PeerConnection;
use orchestration_p2p::peer_error::PeerError;
use orchestration_p2p::service_endpoint::ServiceEndpoint;

pub(super) async fn serve_over_peer_link(
    endpoint: Arc<ServiceEndpoint>,
    router: Router,
) {
    loop {
        match endpoint.accept().await {
            Ok(connection) => {
                tokio::spawn(serve_connection(connection, router.clone()));
            }
            Err(PeerError::EndpointClosed) => return,
            Err(_failed_handshake) => {}
        }
    }
}

async fn serve_connection(connection: PeerConnection, router: Router) {
    while let Ok(stream) = connection.accept_stream().await {
        let service = TowerToHyperService::new(router.clone());
        let serving = http1::Builder::new()
            .serve_connection(TokioIo::new(stream), service);
        tokio::spawn(serving);
    }
}

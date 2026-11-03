use std::net::TcpListener as StandardTcpListener;
use std::path::Path;
use std::sync::Arc;

use orchestration_p2p::service_endpoint::ServiceEndpoint;
use orchestration_server::{
    EVENTS_LONG_POLL_TIMEOUT, Server, ServerSettings, SharedServer,
    SystemClock, build_router, serve_app_server,
};
use tokio::net::TcpListener;
use tokio::task::JoinSet;

use super::HostedServerAccess;
use super::hosting_logging::log_web_serving_problem;
use super::peer_serving::serve_over_peer_link;
use crate::local_network::ServerAnnouncement;
use crate::node_error::NodeError;
use crate::server_address::ServerAddress;
use crate::server_order::OwnServerRoute;

const LOOPBACK_ADDRESS_PREFIX: &str = "http://127.0.0.1:";

#[derive(Debug)]
pub(crate) struct HostedAppServer {
    server: SharedServer,
    endpoint: Arc<ServiceEndpoint>,
    tasks: JoinSet<()>,
    announcement: ServerAnnouncement,
    local_address: String,
    is_keeping: bool,
}

impl HostedAppServer {
    pub(super) fn start(
        listener: StandardTcpListener,
        endpoint: ServiceEndpoint,
        data_directory: &Path,
    ) -> Result<Self, NodeError> {
        let public_address = ServerAddress::Peer(endpoint.peer_address());
        let settings = ServerSettings {
            data_directory: data_directory.to_path_buf(),
            public_address: public_address.to_string(),
            long_poll_timeout: EVENTS_LONG_POLL_TIMEOUT,
        };
        let server = Server::open(settings, Arc::new(SystemClock))
            .map_err(|problem| describe_hosted_server_problem(&problem))?;
        let server = Arc::new(server);
        let local_port = listener
            .local_addr()
            .map_err(|problem| describe_hosted_server_problem(&problem))?
            .port();
        let listener = TcpListener::from_std(listener)
            .map_err(|problem| describe_hosted_server_problem(&problem))?;
        let announcement = ServerAnnouncement::start(
            &server.device_id().0,
            &public_address,
            endpoint.bound_ipv4_port()?,
        )?;

        let endpoint = Arc::new(endpoint);
        let router = build_router(Arc::clone(&server));
        let mut tasks = JoinSet::new();
        tasks.spawn(serve_on_loopback(listener, Arc::clone(&server)));
        tasks.spawn(serve_over_peer_link(Arc::clone(&endpoint), router));
        Ok(Self {
            server,
            endpoint,
            tasks,
            announcement,
            local_address: format!("{LOOPBACK_ADDRESS_PREFIX}{local_port}"),
            is_keeping: false,
        })
    }

    pub(crate) fn server(&self) -> SharedServer {
        Arc::clone(&self.server)
    }

    pub(crate) fn endpoint(&self) -> Arc<ServiceEndpoint> {
        Arc::clone(&self.endpoint)
    }

    pub(crate) fn own_route(&self) -> OwnServerRoute {
        OwnServerRoute {
            endpoint_public_key: self
                .endpoint
                .peer_address()
                .endpoint_public_key,
            local_address: ServerAddress::Web(self.local_address.clone()),
        }
    }

    pub(super) fn is_keeping(&self) -> bool {
        self.is_keeping
    }

    pub(super) fn start_keeping(
        &mut self,
        keeping: impl Future<Output = ()> + Send + 'static,
    ) {
        self.tasks.spawn(keeping);
        self.is_keeping = true;
    }

    pub(super) fn describe_access(
        &self,
    ) -> Result<HostedServerAccess, NodeError> {
        let setup_code = self
            .server
            .read_setup_code()
            .map_err(|problem| describe_hosted_server_problem(&problem))?;
        Ok(HostedServerAccess {
            local_address: self.local_address.clone(),
            setup_code,
        })
    }

    pub(crate) fn public_address(&self) -> ServerAddress {
        ServerAddress::Peer(self.endpoint.peer_address())
    }

    pub(super) async fn stop(mut self) {
        self.endpoint.close().await;
        self.tasks.shutdown().await;
    }
}

impl Drop for HostedAppServer {
    fn drop(&mut self) {
        self.announcement.stop();
    }
}

async fn serve_on_loopback(listener: TcpListener, server: SharedServer) {
    if let Err(problem) = serve_app_server(listener, server).await {
        log_web_serving_problem(&problem);
    }
}

fn describe_hosted_server_problem(problem: &impl ToString) -> NodeError {
    NodeError::HostedServerFailed(problem.to_string())
}

use std::net::TcpListener;
use std::path::Path;
use std::time::Duration;

use orchestration_api::server_group::JoinServerGroupRequest;
use orchestration_core::device::DeviceRole;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::{ServerMember, ServerStanding};
use orchestration_p2p::service_endpoint::ServiceEndpoint;
use orchestration_server::{REPLICA_WAIT, Server, StateStorage};

use super::group_keeping::{describe_server_problem, sign_own_member};
use super::hosted_endpoint::bind_hosted_endpoint;
use super::hosted_listener::bind_hosted_listener;
use super::hosting_logging::log_backup_cleanup_problem;
use super::{HostedAppServer, forget_hosted_app_server, keep_server_group};
use crate::device_files::HostedServerRecord;
use crate::node::{DeviceSession, Node};
use crate::node_error::NodeError;

const WHOLE_STATE_REVISION: u64 = 0;
const FIRST_COPY_MARGIN: Duration = Duration::from_secs(5);

pub(crate) async fn start_server_backup(node: &Node) -> Result<(), NodeError> {
    let session = node.open_session()?;
    if session.account.device.role == DeviceRole::Runner {
        return Err(NodeError::BackupNeedsClient);
    }
    let is_hosting = node.lock_hosted_app_server().is_some()
        || node.device_files().load_hosted_server()?.is_some();
    if is_hosting {
        return Err(NodeError::AlreadyKeepingServer);
    }
    let group = session.client().read_server_group().await?.group;
    let leader_id = group
        .active_server_id()
        .cloned()
        .ok_or(NodeError::ServerKeepsNoBackups)?;

    let record = HostedServerRecord {
        port: node.app_server_port(),
    };
    let listener = bind_hosted_listener(record.port)?;
    let server_directory = node.device_files().hosted_server_directory();
    let endpoint =
        bind_hosted_endpoint(&server_directory, node.peer_relay()).await?;
    let server_identity = StateStorage::new(server_directory.clone())
        .load_or_create_identity()
        .map_err(|problem| describe_server_problem(&problem))?;
    let server_key = server_identity.public_identity().signing_public_key;
    let member = sign_own_member(&session.identity, &endpoint, server_key);
    let copied =
        join_and_copy(&session, member, &leader_id, &server_directory).await;
    if let Err(problem) = copied {
        endpoint.close().await;
        abandon_backup(node, &session).await;
        return Err(problem);
    }
    let serving = serve_backup(node, listener, endpoint, &record);
    if let Err(problem) = serving {
        abandon_backup(node, &session).await;
        return Err(problem);
    }
    Ok(())
}

pub(crate) async fn stop_server_backup(node: &Node) -> Result<(), NodeError> {
    let session = node.open_session()?;
    let standing = node
        .lock_hosted_app_server()
        .as_ref()
        .map(|hosted| hosted.server().standing());
    let Some(standing) = standing else {
        return Err(NodeError::NotKeepingServer);
    };
    if standing == ServerStanding::Active {
        return Err(NodeError::ActiveServerCannotStop);
    }
    let device_id = session.identity.device_id();
    session.client().leave_server_group(&device_id).await?;
    forget_hosted_app_server(node).await?;
    node.reconnect_app_server()
}

async fn join_and_copy(
    session: &DeviceSession,
    member: ServerMember,
    leader_id: &DeviceId,
    server_directory: &Path,
) -> Result<(), NodeError> {
    let request = JoinServerGroupRequest { member };
    session.client().join_server_group(&request).await?;
    let longest_wait = REPLICA_WAIT + FIRST_COPY_MARGIN;
    let replica_bytes = session
        .client()
        .fetch_replica(WHOLE_STATE_REVISION, longest_wait)
        .await?
        .ok_or(NodeError::NoServerCopy)?;
    Server::seed_replica(server_directory, &replica_bytes, leader_id)
        .map_err(|problem| describe_server_problem(&problem))
}

fn serve_backup(
    node: &Node,
    listener: TcpListener,
    endpoint: ServiceEndpoint,
    record: &HostedServerRecord,
) -> Result<(), NodeError> {
    let server_directory = node.device_files().hosted_server_directory();
    let hosted =
        HostedAppServer::start(listener, endpoint, &server_directory)?;
    *node.lock_hosted_app_server() = Some(hosted);
    node.device_files().save_hosted_server(record)?;
    keep_server_group(node)
}

async fn abandon_backup(node: &Node, session: &DeviceSession) {
    let device_id = session.identity.device_id();
    if let Err(problem) = session.client().leave_server_group(&device_id).await
    {
        log_backup_cleanup_problem(&problem);
    }
    if let Err(problem) = forget_hosted_app_server(node).await {
        log_backup_cleanup_problem(&problem);
    }
}

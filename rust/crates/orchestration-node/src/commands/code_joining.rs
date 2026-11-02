use std::time::Duration;

use orchestration_api::accounts::{JoinAccepted, JoinRequest, PairingNonce};
use orchestration_core::device::DeviceRole;
use orchestration_core::naming::validate_name;
use orchestration_security::pairing::{
    PairingCode, PairingPublicKeys, generate_pairing_nonce,
};
use tokio::time::timeout;

use super::device_registration::register_this_device;
use crate::code_rendezvous::find_server_by_code;
use crate::device_files::{PendingJoin, PendingJoinView};
use crate::local_network::LocalNetworkSearch;
use crate::node::Node;
use crate::node_error::NodeError;
use crate::server_address::ServerAddress;
use crate::server_client::ServerClient;

const LOCAL_NETWORK_SEARCH_LIMIT: Duration = Duration::from_secs(5);

type AcceptingServer = (ServerClient, JoinAccepted);

#[derive(Debug)]
pub(super) struct CodeJoin {
    pub(super) server_address: Option<String>,
    pub(super) code: String,
    pub(super) device_name: String,
    pub(super) role: DeviceRole,
}

pub(super) async fn join_with_code(
    node: &Node,
    join: CodeJoin,
) -> Result<PendingJoinView, NodeError> {
    let pairing_code = PairingCode::parse(&join.code)?;
    validate_name(&join.device_name)?;
    if node.device_files().load_account()?.is_some() {
        return Err(NodeError::AccountExists);
    }

    let identity = node.find_or_create_identity()?;
    let join_request = JoinRequest {
        code: String::from(pairing_code.clone()),
        device: register_this_device(&identity, join.device_name, join.role),
    };
    let (server, accepted) = match join.server_address {
        Some(server_text) => {
            let server_address = ServerAddress::parse(&server_text)?;
            join_server_at(node, &server_address, &join_request).await?
        }
        None => {
            join_server_by_code(node, &pairing_code, &join_request).await?
        }
    };
    node.remember_app_server(&server)?;

    let joiner_nonce = generate_pairing_nonce()?;
    let nonce = PairingNonce {
        nonce: joiner_nonce.clone(),
    };
    server.send_joiner_nonce(accepted.join_id, &nonce).await?;
    let pending_join = PendingJoin {
        join_id: accepted.join_id,
        display_code: pairing_code.display(),
        joiner_nonce,
        approver: PairingPublicKeys {
            signing_public_key: accepted.approver_signing_public_key,
            sealing_public_key: accepted.approver_sealing_public_key,
        },
        approver_commitment: accepted.approver_commitment,
    };
    node.device_files().save_pending_join(&pending_join)?;
    Ok(pending_join.view())
}

async fn join_server_at(
    node: &Node,
    server_address: &ServerAddress,
    join_request: &JoinRequest,
) -> Result<AcceptingServer, NodeError> {
    let server = node.connect_to_server(server_address)?;
    let accepted = server.join_with_code(join_request).await?;
    Ok((server, accepted))
}

async fn join_server_by_code(
    node: &Node,
    code: &PairingCode,
    join_request: &JoinRequest,
) -> Result<AcceptingServer, NodeError> {
    let local_join = join_server_on_local_network(node, join_request).await;
    match local_join {
        Err(NodeError::NoServerAcceptedCode) if node.crosses_networks() => {
            join_server_through_rendezvous(node, code, join_request).await
        }
        _ => local_join,
    }
}

async fn join_server_on_local_network(
    node: &Node,
    join_request: &JoinRequest,
) -> Result<AcceptingServer, NodeError> {
    let mut search = LocalNetworkSearch::start()?;
    let trying = try_each_announced_server(node, &mut search, join_request);
    match timeout(LOCAL_NETWORK_SEARCH_LIMIT, trying).await {
        Ok(joined) => joined,
        Err(_elapsed) => Err(NodeError::NoServerAcceptedCode),
    }
}

async fn try_each_announced_server(
    node: &Node,
    search: &mut LocalNetworkSearch,
    join_request: &JoinRequest,
) -> Result<AcceptingServer, NodeError> {
    while let Some(server_address) = search.next_server_address().await {
        let attempt =
            join_server_at(node, &server_address, join_request).await;
        if let Ok(joined) = attempt {
            return Ok(joined);
        }
    }
    Err(NodeError::NoServerAcceptedCode)
}

async fn join_server_through_rendezvous(
    node: &Node,
    code: &PairingCode,
    join_request: &JoinRequest,
) -> Result<AcceptingServer, NodeError> {
    let board = &node.peer_side()?.record_board;
    let server_address = find_server_by_code(board, code).await?;
    join_server_at(node, &server_address, join_request).await
}

use std::sync::Arc;

use chrono::{DateTime, Utc};
use orchestration_p2p::record_board::RecordBoard;
use orchestration_security::pairing::PairingCode;

use super::published_codes::PublishedCodes;
use super::{publish_server_for_code, withdraw_code};
use crate::node::Node;
use crate::node_error::NodeError;
use crate::server_address::ServerAddress;

pub(crate) async fn announce_code(
    node: &Node,
    code: &PairingCode,
    expires_at: DateTime<Utc>,
) -> Option<String> {
    if !node.crosses_networks() {
        return None;
    }
    let published_codes = node.published_codes();
    match publish_announcement(node, code, expires_at).await {
        Ok(board) => {
            published_codes.record_published(code);
            schedule_expiry(published_codes, board, code.clone(), expires_at);
            None
        }
        Err(problem) => {
            published_codes.record_problem(&problem);
            Some(problem.to_string())
        }
    }
}

pub(crate) async fn withdraw_announced_code(node: &Node, code: &PairingCode) {
    let Ok(peer_side) = node.peer_side() else {
        return;
    };
    let published_codes = node.published_codes();
    let board = &peer_side.record_board;
    withdraw_when_published(&published_codes, board, code).await;
}

async fn publish_announcement(
    node: &Node,
    code: &PairingCode,
    expires_at: DateTime<Utc>,
) -> Result<RecordBoard, NodeError> {
    let board = node.peer_side()?.record_board.clone();
    let server_address = find_public_server_address(node)?;
    publish_server_for_code(&board, code, &server_address, expires_at).await?;
    Ok(board)
}

fn find_public_server_address(
    node: &Node,
) -> Result<ServerAddress, NodeError> {
    if let Some(hosted_address) = node.hosted_server_address() {
        return Ok(hosted_address);
    }
    let server = node.app_server()?;
    Ok(server.address().clone())
}

fn schedule_expiry(
    published_codes: Arc<PublishedCodes>,
    board: RecordBoard,
    code: PairingCode,
    expires_at: DateTime<Utc>,
) {
    let time_left = expires_at - Utc::now();
    let wait = time_left.to_std().unwrap_or_default();
    tokio::spawn(async move {
        tokio::time::sleep(wait).await;
        withdraw_when_published(&published_codes, &board, &code).await;
    });
}

async fn withdraw_when_published(
    published_codes: &PublishedCodes,
    board: &RecordBoard,
    code: &PairingCode,
) {
    if !published_codes.take(code) {
        return;
    }
    if let Err(problem) = withdraw_code(board, code).await {
        published_codes.record_problem(&problem);
    }
}

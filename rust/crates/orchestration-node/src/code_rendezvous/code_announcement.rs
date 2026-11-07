use std::time::Duration;

use chrono::{DateTime, Utc};
use orchestration_p2p::peer_error::PeerError;
use orchestration_p2p::record_board::RecordBoard;
use orchestration_security::pairing::PairingCode;
use tokio::time::timeout;

use super::published_codes::PublishedCodes;
use super::{publish_server_for_code, withdraw_code};
use crate::node::Node;
use crate::node_error::NodeError;
use crate::server_address::ServerAddress;

const CODE_PUBLISH_WAIT_LIMIT: Duration = Duration::from_secs(5);

pub(crate) async fn announce_code(
    node: &Node,
    code: &PairingCode,
    expires_at: DateTime<Utc>,
) -> Option<String> {
    if !node.crosses_networks() {
        return None;
    }
    let published_codes = node.published_codes();
    let outcome = publish_within_limit(node, code, expires_at).await;
    let problem = match outcome {
        Ok(()) => {
            published_codes.record_published(code);
            None
        }
        Err(problem) => {
            published_codes.record_problem(code, &problem);
            Some(problem.to_string())
        }
    };
    schedule_expiry(node, code, expires_at);
    problem
}

pub(crate) async fn withdraw_announced_code(node: &Node, code: &PairingCode) {
    let published_codes = node.published_codes();
    let peer_side = node.peer_side().ok();
    let board = peer_side.map(|peer_side| &peer_side.record_board);
    end_announcement(&published_codes, board, code).await;
}

async fn publish_within_limit(
    node: &Node,
    code: &PairingCode,
    expires_at: DateTime<Utc>,
) -> Result<(), NodeError> {
    let publishing = publish_announcement(node, code, expires_at);
    match timeout(CODE_PUBLISH_WAIT_LIMIT, publishing).await {
        Ok(published) => published,
        Err(_elapsed) => Err(describe_silent_board()),
    }
}

async fn publish_announcement(
    node: &Node,
    code: &PairingCode,
    expires_at: DateTime<Utc>,
) -> Result<(), NodeError> {
    let board = &node.peer_side()?.record_board;
    let server_address = find_public_server_address(node)?;
    publish_server_for_code(board, code, &server_address, expires_at).await
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

fn describe_silent_board() -> NodeError {
    let wait_seconds = CODE_PUBLISH_WAIT_LIMIT.as_secs();
    let silence = format!("no answer within {wait_seconds} seconds");
    NodeError::Rendezvous(PeerError::RecordBoardUnreachable(silence))
}

fn schedule_expiry(
    node: &Node,
    code: &PairingCode,
    expires_at: DateTime<Utc>,
) {
    let published_codes = node.published_codes();
    let peer_side = node.peer_side().ok();
    let board = peer_side.map(|peer_side| peer_side.record_board.clone());
    let expiring_code = code.clone();
    let time_left = expires_at - Utc::now();
    let wait = time_left.to_std().unwrap_or_default();
    tokio::spawn(async move {
        tokio::time::sleep(wait).await;
        end_announcement(&published_codes, board.as_ref(), &expiring_code)
            .await;
    });
}

async fn end_announcement(
    published_codes: &PublishedCodes,
    board: Option<&RecordBoard>,
    code: &PairingCode,
) {
    published_codes.forget_problem_of(code);
    let Some(board) = board else {
        return;
    };
    withdraw_when_published(published_codes, board, code).await;
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
        published_codes.record_problem(code, &problem);
    }
}

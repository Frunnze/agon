use orchestration_api::accounts::{AccountView, JoinStatus};
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::pairing::{
    PairingCode, PairingPublicKeys, PairingTranscript,
    verify_approver_commitment,
};
use serde::Serialize;

use super::account_commands::{AccountSummary, summarize_account};
use super::shown_words::list_fingerprint_words;
use crate::content_sealing::WorkspaceKeyring;
use crate::device_files::PendingJoin;
use crate::node::Node;
use crate::node_error::NodeError;

#[derive(Debug, Serialize)]
#[serde(rename_all = "snake_case")]
enum JoinState {
    Waiting,
    Approved,
    Rejected,
    Expired,
}

#[derive(Debug, Serialize)]
pub(super) struct JoinStatusView {
    state: JoinState,
    fingerprint_words: Vec<String>,
    #[serde(flatten)]
    account: Option<AccountSummary>,
}

pub(super) async fn read_join_status(
    node: &Node,
) -> Result<JoinStatusView, NodeError> {
    let pending_join = node
        .device_files()
        .load_pending_join()?
        .ok_or(NodeError::NoPendingJoin)?;
    let server = node.app_server()?;
    let status = server.read_join_status(pending_join.join_id).await?;

    let finished = match status {
        JoinStatus::Waiting { approver_nonce } => {
            let mut fingerprint_words = Vec::new();
            if let Some(nonce) = approver_nonce {
                let identity = node.find_or_create_identity()?;
                fingerprint_words =
                    compute_joiner_words(&identity, &pending_join, nonce)?;
            }
            return Ok(JoinStatusView {
                state: JoinState::Waiting,
                fingerprint_words,
                account: None,
            });
        }
        JoinStatus::Approved {
            account,
            approver_nonce,
        } => {
            let identity = node.find_or_create_identity()?;
            let fingerprint_words = compute_joiner_words(
                &identity,
                &pending_join,
                approver_nonce,
            )?;
            accept_account(&identity, &account)?;
            node.device_files().save_account(&account)?;
            JoinStatusView {
                state: JoinState::Approved,
                fingerprint_words,
                account: Some(summarize_account(&account)),
            }
        }
        JoinStatus::Rejected => ended_join(JoinState::Rejected),
        JoinStatus::Expired => ended_join(JoinState::Expired),
    };
    node.device_files().remove_pending_join()?;
    Ok(finished)
}

fn ended_join(state: JoinState) -> JoinStatusView {
    JoinStatusView {
        state,
        fingerprint_words: Vec::new(),
        account: None,
    }
}

fn compute_joiner_words(
    identity: &DeviceIdentity,
    pending_join: &PendingJoin,
    approver_nonce: Vec<u8>,
) -> Result<Vec<String>, NodeError> {
    let code = PairingCode::parse(&pending_join.display_code)?;
    verify_approver_commitment(
        &code,
        &pending_join.approver,
        &approver_nonce,
        &pending_join.approver_commitment,
    )?;
    let transcript = PairingTranscript {
        code,
        joiner: PairingPublicKeys::of_identity(identity),
        approver: pending_join.approver.clone(),
        joiner_nonce: pending_join.joiner_nonce.clone(),
        approver_nonce,
    };
    Ok(list_fingerprint_words(&transcript))
}

fn accept_account(
    identity: &DeviceIdentity,
    account: &AccountView,
) -> Result<(), NodeError> {
    let own_signing_key = identity.public_identity().signing_public_key;
    if account.device.signing_public_key != own_signing_key {
        return Err(NodeError::UnexpectedAnswer(
            "the approved account belongs to another device".to_owned(),
        ));
    }
    WorkspaceKeyring::open_sealed_keys(
        identity,
        &account.sealed_workspace_keys,
    )?;
    Ok(())
}

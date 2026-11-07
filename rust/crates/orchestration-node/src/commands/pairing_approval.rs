use chrono::{DateTime, Utc};
use orchestration_api::accounts::{
    ApprovePairingRequest, JoiningDevice, PairingCommitment, PairingNonce,
    SealedWorkspaceKey,
};
use orchestration_core::device::{DeviceKind, DeviceRole, HardwareKeyKind};
use orchestration_core::identifiers::WorkspaceId;
use orchestration_security::pairing::{
    PairingCode, PairingPublicKeys, PairingTranscript,
    commit_to_approver_nonce, generate_pairing_nonce,
};
use serde::Serialize;

use super::pairing_commands::end_pairing_here;
use super::shown_words::list_fingerprint_words;
use crate::code_rendezvous::{announce_code, withdraw_announced_code};
use crate::content_sealing::seal_workspace_key;
use crate::node::{DeviceSession, Node};
use crate::node_error::NodeError;

#[derive(Debug, Serialize)]
pub(super) struct PairingRequestScreen {
    code: String,
    display_code: String,
    started_at: DateTime<Utc>,
    expires_at: DateTime<Utc>,
    joining: Option<JoiningDeviceScreen>,
}

#[derive(Debug, Serialize)]
pub(super) struct StartedPairing {
    #[serde(flatten)]
    screen: PairingRequestScreen,
    rendezvous_problem: Option<String>,
}

#[derive(Debug, Serialize)]
struct JoiningDeviceScreen {
    name: String,
    role: DeviceRole,
    kind: DeviceKind,
    key_kind: HardwareKeyKind,
    sealing_public_key: Vec<u8>,
    fingerprint_words: Vec<String>,
}

pub(super) async fn start_pairing(
    node: &Node,
) -> Result<StartedPairing, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    let created = client.start_pairing_session().await?;
    let pairing_code = PairingCode::parse(&created.code)?;
    let canonical = String::from(pairing_code.clone());

    let approver_nonce = generate_pairing_nonce()?;
    let approver = PairingPublicKeys::of_identity(&session.identity);
    let commitment = PairingCommitment {
        commitment: commit_to_approver_nonce(
            &pairing_code,
            &approver,
            &approver_nonce,
        ),
    };
    client.commit_pairing(&canonical, &commitment).await?;
    node.approver_pairings()
        .remember_nonce(&pairing_code, approver_nonce);

    let rendezvous_problem =
        announce_code(node, &pairing_code, created.expires_at).await;
    let screen = PairingRequestScreen {
        display_code: pairing_code.display(),
        code: canonical,
        started_at: created.started_at,
        expires_at: created.expires_at,
        joining: None,
    };
    Ok(StartedPairing {
        screen,
        rendezvous_problem,
    })
}

pub(super) async fn read_pairing_request(
    node: &Node,
    code: &str,
) -> Result<PairingRequestScreen, NodeError> {
    let session = node.open_session()?;
    let pairing_code = PairingCode::parse(code)?;
    let canonical = String::from(pairing_code.clone());
    let request = session.client().read_pairing_request(&canonical).await?;

    let mut joining_screen = None;
    if let Some(joining) = &request.joining {
        withdraw_announced_code(node, &pairing_code).await;
        let transcript =
            agree_on_transcript(node, &session, &pairing_code, joining)
                .await?;
        joining_screen = transcript
            .map(|transcript| describe_joining(joining, &transcript));
    }
    Ok(PairingRequestScreen {
        code: canonical,
        display_code: pairing_code.display(),
        started_at: request.started_at,
        expires_at: request.expires_at,
        joining: joining_screen,
    })
}

pub(super) async fn approve_pairing(
    node: &Node,
    code: &str,
    workspace_ids: &[WorkspaceId],
) -> Result<(), NodeError> {
    let session = node.open_session()?;
    let pairing_code = PairingCode::parse(code)?;
    let canonical = String::from(pairing_code.clone());
    let request = session.client().read_pairing_request(&canonical).await?;
    let joining = request.joining.ok_or(NodeError::NoJoiningDevice)?;
    let transcript =
        agree_on_transcript(node, &session, &pairing_code, &joining)
            .await?
            .ok_or(NodeError::PairingWordsNotReady)?;

    let mut sealed_workspace_keys = Vec::new();
    for workspace_id in workspace_ids {
        let workspace_key = session.keyring.key_for(*workspace_id)?;
        sealed_workspace_keys.push(SealedWorkspaceKey {
            workspace_id: *workspace_id,
            sealed_key: seal_workspace_key(
                &transcript.joiner.sealing_public_key,
                workspace_key,
            )?,
        });
    }
    let approval = ApprovePairingRequest {
        sealed_workspace_keys,
        approval_signature: transcript.sign_approval(&session.identity)?,
    };
    session
        .client()
        .approve_pairing(&canonical, &approval)
        .await?;
    end_pairing_here(node, &pairing_code).await;
    Ok(())
}

async fn agree_on_transcript(
    node: &Node,
    session: &DeviceSession,
    code: &PairingCode,
    joining: &JoiningDevice,
) -> Result<Option<PairingTranscript>, NodeError> {
    let Some(joiner_nonce) = &joining.joiner_nonce else {
        return Ok(None);
    };
    let pairings = node.approver_pairings();
    let approver_nonce = pairings
        .find_approver_nonce(code)
        .ok_or(NodeError::PairingNotStartedHere)?;

    let candidate = PairingTranscript {
        code: code.clone(),
        joiner: joiner_keys_of(joining),
        approver: PairingPublicKeys::of_identity(&session.identity),
        joiner_nonce: joiner_nonce.clone(),
        approver_nonce,
    };
    let transcript = pairings
        .pin_transcript(candidate)
        .ok_or(NodeError::PairingNotStartedHere)?;
    require_unchanged_join(&transcript, joining)?;

    if joining.approver_nonce.is_none() {
        let reveal = PairingNonce {
            nonce: transcript.approver_nonce.clone(),
        };
        let canonical = String::from(code.clone());
        session
            .client()
            .reveal_pairing_nonce(&canonical, &reveal)
            .await?;
    }
    Ok(Some(transcript))
}

fn require_unchanged_join(
    transcript: &PairingTranscript,
    joining: &JoiningDevice,
) -> Result<(), NodeError> {
    let pinned_joiner_nonce = Some(&transcript.joiner_nonce);
    let is_same_joiner = transcript.joiner == joiner_keys_of(joining)
        && joining.joiner_nonce.as_ref() == pinned_joiner_nonce;
    let is_own_reveal = joining
        .approver_nonce
        .as_ref()
        .is_none_or(|revealed| *revealed == transcript.approver_nonce);
    if is_same_joiner && is_own_reveal {
        return Ok(());
    }
    Err(NodeError::PairingTranscriptChanged)
}

fn joiner_keys_of(joining: &JoiningDevice) -> PairingPublicKeys {
    PairingPublicKeys {
        signing_public_key: joining.signing_public_key.clone(),
        sealing_public_key: joining.sealing_public_key.clone(),
    }
}

fn describe_joining(
    joining: &JoiningDevice,
    transcript: &PairingTranscript,
) -> JoiningDeviceScreen {
    JoiningDeviceScreen {
        name: joining.name.clone(),
        role: joining.role,
        kind: joining.kind,
        key_kind: joining.key_kind,
        sealing_public_key: transcript.joiner.sealing_public_key.clone(),
        fingerprint_words: list_fingerprint_words(transcript),
    }
}

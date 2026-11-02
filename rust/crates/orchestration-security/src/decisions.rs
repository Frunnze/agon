use chrono::{DateTime, Utc};
use orchestration_core::approval::{
    ApprovalAction, ApprovalDecision, ApprovalRequest, SignedDecision,
};
use orchestration_core::identifiers::{ApprovalId, DeviceId, RunId};
use serde::Serialize;

use crate::canonical_message::encode_canonical_message;
use crate::error::SecurityError;
use crate::identity::{DeviceIdentity, device_id_for, verify_signature};

const DECISION_DOMAIN: &str = "orchestration-approval-decision-v1";

#[derive(Serialize)]
struct DecisionStatement<'statement> {
    request_id: &'statement ApprovalId,
    run_id: &'statement Option<RunId>,
    action: &'statement ApprovalAction,
    requested_by: &'statement DeviceId,
    requested_at: &'statement DateTime<Utc>,
    decision: ApprovalDecision,
    decided_by: &'statement DeviceId,
    decided_at: &'statement DateTime<Utc>,
}

pub fn sign_decision(
    identity: &DeviceIdentity,
    request: &ApprovalRequest,
    decision: ApprovalDecision,
    decided_at: DateTime<Utc>,
) -> Result<SignedDecision, SecurityError> {
    let decided_by = identity.device_id();
    let message =
        encode_decision_message(request, decision, &decided_by, &decided_at)?;

    Ok(SignedDecision {
        decision,
        signature: identity.sign(&message),
        decided_by,
        decided_at,
    })
}

pub fn verify_decision(
    request: &ApprovalRequest,
    signed_decision: &SignedDecision,
    signer_key: &[u8],
) -> Result<(), SecurityError> {
    if device_id_for(signer_key) != signed_decision.decided_by {
        return Err(SecurityError::SignerMismatch);
    }

    let message = encode_decision_message(
        request,
        signed_decision.decision,
        &signed_decision.decided_by,
        &signed_decision.decided_at,
    )?;

    verify_signature(signer_key, &message, &signed_decision.signature)
}

fn encode_decision_message(
    request: &ApprovalRequest,
    decision: ApprovalDecision,
    decided_by: &DeviceId,
    decided_at: &DateTime<Utc>,
) -> Result<Vec<u8>, SecurityError> {
    let statement = DecisionStatement {
        request_id: &request.id,
        run_id: &request.run_id,
        action: &request.action,
        requested_by: &request.requested_by,
        requested_at: &request.requested_at,
        decision,
        decided_by,
        decided_at,
    };
    let statement_json = serde_json::to_vec(&statement)
        .map_err(|_| SecurityError::SerializationFailed)?;

    Ok(encode_canonical_message(
        DECISION_DOMAIN,
        &[&statement_json],
    ))
}

use std::time::Duration;

use orchestration_api::work::CreateApprovalRequest;
use orchestration_core::approval::{
    ApprovalDecision, ApprovalRequest, SignedDecision,
};
use orchestration_core::device::Device;
use orchestration_core::identifiers::ApprovalId;
use orchestration_security::decisions::verify_decision;

use super::transient_retry::retry_transient;
use crate::device_roles::can_decide_approvals;
use crate::node::Node;
use crate::node_error::NodeError;
use crate::server_client::SignedServerClient;

const DECISION_CHECK_INTERVAL: Duration = Duration::from_secs(1);

pub(super) async fn wait_for_decision(
    node: &Node,
    request: &CreateApprovalRequest,
) -> Result<ApprovalDecision, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    let created = retry_transient(|| client.create_approval(request)).await?;

    loop {
        tokio::time::sleep(DECISION_CHECK_INTERVAL).await;
        let approval =
            retry_transient(|| read_approval(&client, created.id)).await?;
        let Some(signed_decision) = &approval.decision else {
            continue;
        };

        if approval.run_id != request.run_id
            || approval.action != request.action
        {
            return Err(NodeError::UntrustedDecision(
                "the approval no longer matches the request".to_owned(),
            ));
        }
        let devices = retry_transient(|| client.list_devices()).await?;
        verify_trusted_decision(&approval, signed_decision, &devices)?;
        return Ok(signed_decision.decision);
    }
}

async fn read_approval(
    client: &SignedServerClient<'_>,
    approval_id: ApprovalId,
) -> Result<ApprovalRequest, NodeError> {
    let approvals = client.list_approvals().await?;
    let found_approval = approvals
        .into_iter()
        .find(|approval| approval.id == approval_id);
    found_approval.ok_or_else(|| NodeError::NotFound {
        kind: "approval",
        identifier: approval_id.0.to_string(),
    })
}

fn verify_trusted_decision(
    approval: &ApprovalRequest,
    signed_decision: &SignedDecision,
    devices: &[Device],
) -> Result<(), NodeError> {
    let decider = devices.iter().find(|device| {
        device.id == signed_decision.decided_by
            && !device.revoked
            && can_decide_approvals(device.role)
    });
    let Some(decider) = decider else {
        return Err(NodeError::UntrustedDecision(
            "the decision comes from no trusted client device".to_owned(),
        ));
    };
    verify_decision(approval, signed_decision, &decider.signing_public_key)
        .map_err(|problem| NodeError::UntrustedDecision(problem.to_string()))
}

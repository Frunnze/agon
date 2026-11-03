use chrono::{DateTime, Utc};
use orchestration_api::catalog::WorkflowListing;
use orchestration_core::device::Device;
use orchestration_core::document_diff::{DiffLine, diff_lines};
use orchestration_core::identifiers::{DeviceId, WorkflowId};
use orchestration_core::workflow::{SignatureState, Workflow};
use orchestration_core::workflow_document::render_workflow_document;
use orchestration_core::workflow_graph::agents_in_order;
use orchestration_security::documents::signature_state;
use serde::Serialize;

use crate::content_sealing::{
    WorkspaceKeyring, open_sealed_document, open_workflow,
};
use crate::node_error::NodeError;
use crate::server_client::SignedServerClient;

#[derive(Debug, Serialize)]
pub(super) struct WorkflowView {
    workflow: Workflow,
    agent_names: Vec<String>,
    document: String,
    signature_state: SignatureState,
    changes: Vec<DiffLine>,
    signed_at: Option<DateTime<Utc>>,
    changed_at: Option<DateTime<Utc>>,
    changed_by: Option<DeviceId>,
    changed_by_name: Option<String>,
}

pub(super) fn build_workflow_view(
    keyring: &WorkspaceKeyring,
    listing: &WorkflowListing,
    devices: &[Device],
) -> Result<WorkflowView, NodeError> {
    let stored_workflow = &listing.workflow;
    let opened_workflow = open_workflow(keyring, stored_workflow)?;
    let sealed_document = render_workflow_document(stored_workflow);
    let signature = stored_workflow.signature.as_ref();
    let state = read_signature_state(stored_workflow, devices);

    let mut changes = Vec::new();
    if let Some(signature) = signature
        && state != SignatureState::Signed
    {
        let signed_text =
            open_sealed_document(keyring, &signature.signed_document)?;
        let current_text = open_sealed_document(keyring, &sealed_document)?;
        changes = diff_lines(&signed_text, &current_text);
    }
    let agent_names = agents_in_order(&opened_workflow)
        .iter()
        .map(|agent| agent.name.clone())
        .collect();

    let changed_by_name = listing.changed_by.as_ref().and_then(|changer| {
        devices
            .iter()
            .find(|device| &device.id == changer)
            .map(|device| device.name.clone())
    });

    Ok(WorkflowView {
        document: render_workflow_document(&opened_workflow),
        workflow: opened_workflow,
        agent_names,
        signature_state: state,
        changes,
        signed_at: listing.signed_at,
        changed_at: listing.changed_at,
        changed_by: listing.changed_by.clone(),
        changed_by_name,
    })
}

pub(super) async fn read_stored_workflow(
    client: &SignedServerClient<'_>,
    workflow_id: WorkflowId,
) -> Result<WorkflowListing, NodeError> {
    let listings = client.list_workflows().await?;
    let found_workflow = listings
        .into_iter()
        .find(|listing| listing.workflow.id == workflow_id);
    found_workflow.ok_or_else(|| NodeError::NotFound {
        kind: "workflow",
        identifier: workflow_id.0.to_string(),
    })
}

pub(super) fn read_signature_state(
    stored_workflow: &Workflow,
    devices: &[Device],
) -> SignatureState {
    let sealed_document = render_workflow_document(stored_workflow);
    let signature = stored_workflow.signature.as_ref();
    let signer_key = signature
        .and_then(|signature| find_signer(devices, &signature.signed_by))
        .map(|signer| signer.signing_public_key.as_slice());
    signature_state(signature, &sealed_document, signer_key)
}

fn find_signer<'devices>(
    devices: &'devices [Device],
    signer_id: &DeviceId,
) -> Option<&'devices Device> {
    devices
        .iter()
        .find(|device| &device.id == signer_id && !device.revoked)
}

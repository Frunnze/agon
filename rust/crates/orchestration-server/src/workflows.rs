use axum::Json;
use axum::extract::State;
use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use orchestration_api::catalog::{
    SaveWorkflowRequest, SignWorkflowRequest, WorkflowListing,
};
use orchestration_api::updates::ChangeTopic;
use orchestration_core::identifiers::{DeviceId, WorkflowId};
use orchestration_core::naming::validate_name;
use orchestration_core::workflow::{
    SignatureState, Workflow, WorkflowSignature,
};
use orchestration_core::workflow_document::render_workflow_document;
use orchestration_core::workflow_graph::validate_workflow;
use orchestration_security::documents::signature_state;
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::device_registration::signing_key_of;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::server::SharedServer;
use crate::stored_state::{StoredState, WorkflowRecord};
use crate::workflow_listings::{ChangeStamp, describe_listing, stamp_change};

const UNKNOWN_WORKFLOW: &str = "the workflow";

pub async fn list_workflows(
    State(server): State<SharedServer>,
    _request: SignedRequest,
) -> Result<Json<Vec<WorkflowListing>>, ServerError> {
    let listings = server.read(|state| {
        Ok(state.workflows.values().map(describe_listing).collect())
    })?;
    Ok(Json(listings))
}

pub async fn create_workflow(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<(StatusCode, Json<Workflow>), ServerError> {
    request.caller.require_client()?;
    let save_request: SaveWorkflowRequest = parse_json_body(&request.body)?;
    let caller_id = &request.caller.device_id;
    let workflow = server.apply(caller_id, |state, now| {
        let stamp = ChangeStamp {
            at: now,
            by: caller_id,
        };
        add_workflow(state, &save_request.workflow, stamp)
    })?;
    Ok((StatusCode::CREATED, Json(workflow)))
}

pub async fn update_workflow(
    State(server): State<SharedServer>,
    PathValue(workflow_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Workflow>, ServerError> {
    request.caller.require_client()?;
    let save_request: SaveWorkflowRequest = parse_json_body(&request.body)?;
    let workflow_id = WorkflowId(workflow_uuid);
    let caller_id = &request.caller.device_id;
    let workflow = server.apply(caller_id, |state, now| {
        let stamp = ChangeStamp {
            at: now,
            by: caller_id,
        };
        change_workflow(state, workflow_id, &save_request.workflow, stamp)
    })?;
    Ok(Json(workflow))
}

pub async fn sign_workflow(
    State(server): State<SharedServer>,
    PathValue(workflow_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Workflow>, ServerError> {
    request.caller.require_client()?;
    let sign_request: SignWorkflowRequest = parse_json_body(&request.body)?;
    let workflow_id = WorkflowId(workflow_uuid);
    let caller_id = &request.caller.device_id;
    let signature = &sign_request.signature;
    let workflow = server.apply(caller_id, |state, now| {
        store_signature(state, workflow_id, caller_id, signature, now)
    })?;
    Ok(Json(workflow))
}

pub async fn discard_workflow_change(
    State(server): State<SharedServer>,
    PathValue(workflow_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Workflow>, ServerError> {
    request.caller.require_client()?;
    let workflow_id = WorkflowId(workflow_uuid);
    let caller_id = &request.caller.device_id;
    let workflow = server.apply(caller_id, |state, now| {
        let stamp = ChangeStamp {
            at: now,
            by: caller_id,
        };
        restore_signed_version(state, workflow_id, stamp)
    })?;
    Ok(Json(workflow))
}

pub fn signed_workflow(
    state: &StoredState,
    workflow_id: WorkflowId,
) -> Result<&Workflow, ServerError> {
    let record = find_workflow(state, workflow_id)?;
    let current = &record.current;
    let signer_key = current
        .signature
        .as_ref()
        .and_then(|signature| signing_key_of(state, &signature.signed_by));
    let current_state = signature_state(
        current.signature.as_ref(),
        &render_workflow_document(current),
        signer_key.as_deref(),
    );
    if current_state != SignatureState::Signed {
        return Err(describe_unsigned(current));
    }
    record
        .last_signed
        .as_ref()
        .ok_or_else(|| describe_unsigned(current))
}

fn describe_unsigned(workflow: &Workflow) -> ServerError {
    ServerError::Conflict(format!("workflow {} is not signed", workflow.name))
}

fn find_workflow(
    state: &StoredState,
    workflow_id: WorkflowId,
) -> Result<&WorkflowRecord, ServerError> {
    state
        .workflows
        .get(&workflow_id)
        .ok_or(ServerError::NotFound(UNKNOWN_WORKFLOW))
}

fn check_workflow(workflow: &Workflow) -> Result<(), ServerError> {
    validate_name(&workflow.name)?;
    validate_workflow(workflow)?;
    Ok(())
}

fn add_workflow(
    state: &mut StoredState,
    workflow: &Workflow,
    stamp: ChangeStamp<'_>,
) -> Result<Change<Workflow>, ServerError> {
    check_workflow(workflow)?;
    if state.workflows.contains_key(&workflow.id) {
        return Err(ServerError::Conflict(
            "the workflow already exists".to_owned(),
        ));
    }
    let unsigned = Workflow {
        signature: None,
        ..workflow.clone()
    };
    let mut record = WorkflowRecord {
        current: unsigned.clone(),
        last_signed: None,
        signed_at: None,
        changed_at: None,
        changed_by: None,
    };
    stamp_change(&mut record, stamp);
    state.workflows.insert(unsigned.id, record);
    let event_text = format!("Created workflow {}", unsigned.name);
    Ok(Change::recorded(
        unsigned,
        ChangeTopic::Workflows,
        event_text,
    ))
}

fn change_workflow(
    state: &mut StoredState,
    workflow_id: WorkflowId,
    workflow: &Workflow,
    stamp: ChangeStamp<'_>,
) -> Result<Change<Workflow>, ServerError> {
    if workflow.id != workflow_id {
        return Err(ServerError::Invalid(
            "the workflow id does not match the address".to_owned(),
        ));
    }
    check_workflow(workflow)?;
    let record = state
        .workflows
        .get_mut(&workflow_id)
        .ok_or(ServerError::NotFound(UNKNOWN_WORKFLOW))?;
    let changed = Workflow {
        signature: record.current.signature.clone(),
        ..workflow.clone()
    };
    record.current = changed.clone();
    stamp_change(record, stamp);
    let event_text = format!("Changed workflow {}", changed.name);
    Ok(Change::recorded(
        changed,
        ChangeTopic::Workflows,
        event_text,
    ))
}

fn store_signature(
    state: &mut StoredState,
    workflow_id: WorkflowId,
    signer_id: &DeviceId,
    signature: &WorkflowSignature,
    now: DateTime<Utc>,
) -> Result<Change<Workflow>, ServerError> {
    if signature.signed_by != *signer_id {
        return Err(ServerError::Forbidden(
            "a device can only send its own signature",
        ));
    }
    let signer_key = signing_key_of(state, signer_id)
        .ok_or(ServerError::Forbidden("the signing device is not trusted"))?;
    let record = state
        .workflows
        .get_mut(&workflow_id)
        .ok_or(ServerError::NotFound(UNKNOWN_WORKFLOW))?;
    let document = render_workflow_document(&record.current);
    let offered_state =
        signature_state(Some(signature), &document, Some(&signer_key));
    if offered_state != SignatureState::Signed {
        return Err(ServerError::Invalid(
            "the signature does not match the workflow document".to_owned(),
        ));
    }

    let signed = Workflow {
        signature: Some(signature.clone()),
        ..record.current.clone()
    };
    record.current = signed.clone();
    record.last_signed = Some(signed.clone());
    record.signed_at = Some(now);
    let event_text = format!("Signed workflow {}", signed.name);
    Ok(Change::recorded(signed, ChangeTopic::Workflows, event_text))
}

fn restore_signed_version(
    state: &mut StoredState,
    workflow_id: WorkflowId,
    stamp: ChangeStamp<'_>,
) -> Result<Change<Workflow>, ServerError> {
    let record = state
        .workflows
        .get_mut(&workflow_id)
        .ok_or(ServerError::NotFound(UNKNOWN_WORKFLOW))?;
    let restored = record.last_signed.clone().ok_or_else(|| {
        ServerError::Conflict("the workflow has no signed version".to_owned())
    })?;
    record.current = restored.clone();
    stamp_change(record, stamp);
    let event_text =
        format!("Discarded changes to workflow {}", restored.name);
    Ok(Change::recorded(
        restored,
        ChangeTopic::Workflows,
        event_text,
    ))
}

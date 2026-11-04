use axum::Json;
use axum::body::Bytes;
use axum::extract::State;
use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use orchestration_api::accounts::{AccountView, CreateAccountRequest};
use orchestration_api::updates::ChangeTopic;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::naming::validate_name;
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::workspace::Workspace;
use orchestration_security::identity::device_id_for;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::device_registration::register_device;
use crate::error::ServerError;
use crate::extractors::parse_json_body;
use crate::memberships::grant_workspace;
use crate::server::SharedServer;
use crate::stored_state::StoredState;

pub async fn create_account(
    State(server): State<SharedServer>,
    body: Bytes,
) -> Result<(StatusCode, Json<AccountView>), ServerError> {
    let request: CreateAccountRequest = parse_json_body(&body)?;
    let setup_code_claim = server.claim_setup_code(&request.setup_code)?;
    let device_id = device_id_for(&request.device.signing_public_key);
    let public_address = server.settings().public_address.clone();
    let account_view = server.apply(&device_id, |state, now| {
        open_account(state, &request, &public_address, now)
    })?;
    setup_code_claim.invalidate()?;
    Ok((StatusCode::CREATED, Json(account_view)))
}

pub async fn show_account(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<Json<AccountView>, ServerError> {
    let device_id = &request.caller.device_id;
    let account_view =
        server.read(|state| build_account_view(state, device_id))?;
    Ok(Json(account_view))
}

pub fn build_account_view(
    state: &StoredState,
    device_id: &DeviceId,
) -> Result<AccountView, ServerError> {
    let device = state
        .devices
        .get(device_id)
        .ok_or(ServerError::NotFound("the device"))?
        .clone();
    let workspaces: Vec<Workspace> = device
        .workspaces
        .iter()
        .filter_map(|workspace_id| state.workspaces.get(workspace_id))
        .cloned()
        .collect();
    let sealed_workspace_keys = state
        .workspace_keys
        .get(device_id)
        .cloned()
        .unwrap_or_default();
    Ok(AccountView {
        device,
        workspaces,
        sealed_workspace_keys,
    })
}

fn open_account(
    state: &mut StoredState,
    request: &CreateAccountRequest,
    public_address: &str,
    now: DateTime<Utc>,
) -> Result<Change<AccountView>, ServerError> {
    if !state.devices.is_empty() {
        return Err(ServerError::Conflict(
            "the account already exists".to_owned(),
        ));
    }
    validate_name(&request.workspace_name)?;
    let device = register_device(&request.device, None, now)?;
    let workspace = Workspace {
        id: request.workspace_id,
        name: request.workspace_name.clone(),
        app_server_address: public_address.to_owned(),
        approval_policy: ApprovalPolicy::default(),
        protected_files: ProtectedFiles::default(),
    };

    let device_id = device.id.clone();
    state.devices.insert(device_id.clone(), device);
    state.workspaces.insert(workspace.id, workspace);
    grant_workspace(
        state,
        &device_id,
        request.workspace_id,
        request.sealed_workspace_key.clone(),
    )?;

    let account_view = build_account_view(state, &device_id)?;
    let event_text = format!(
        "Created the account with workspace {}",
        request.workspace_name
    );
    Ok(Change::recorded(
        account_view,
        ChangeTopic::Account,
        event_text,
    ))
}

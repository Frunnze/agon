use axum::Json;
use axum::extract::State;
use orchestration_api::accounts::PublishPeerAddressRequest;
use orchestration_api::updates::ChangeTopic;
use orchestration_core::device::Device;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::peer_address::SignedPeerAddress;
use orchestration_security::peer_addresses::verify_peer_address;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::device_registration::signing_key_of;
use crate::error::ServerError;
use crate::extractors::parse_json_body;
use crate::server::SharedServer;
use crate::stored_state::StoredState;

pub async fn publish_peer_address(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<Json<Device>, ServerError> {
    let publish_request: PublishPeerAddressRequest =
        parse_json_body(&request.body)?;
    let caller_id = &request.caller.device_id;
    let device = server.apply(caller_id, |state, _now| {
        store_peer_address(state, caller_id, &publish_request.address)
    })?;
    Ok(Json(device))
}

fn store_peer_address(
    state: &mut StoredState,
    caller_id: &DeviceId,
    signed_address: &SignedPeerAddress,
) -> Result<Change<Device>, ServerError> {
    if &signed_address.device_id != caller_id {
        return Err(ServerError::Forbidden(
            "a device can only publish its own peer address",
        ));
    }
    let signer_key = signing_key_of(state, caller_id)
        .ok_or(ServerError::Forbidden("the device is not trusted"))?;
    verify_peer_address(signed_address, &signer_key).map_err(|_| {
        ServerError::Invalid(
            "the peer address signature does not match".to_owned(),
        )
    })?;

    let device = state
        .devices
        .get_mut(caller_id)
        .ok_or(ServerError::NotFound("the device"))?;
    device.peer_address = Some(signed_address.clone());
    let event_text = format!("Published the peer address of {}", device.name);
    Ok(Change::recorded(
        device.clone(),
        ChangeTopic::Devices,
        event_text,
    ))
}

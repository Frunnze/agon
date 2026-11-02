use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::{ServerMember, ServerTerm};
use orchestration_security::server_group::{
    verify_server_membership, verify_server_term,
};

use crate::error::ServerError;
use crate::stored_state::StoredState;

pub fn check_member(
    state: &StoredState,
    member: &ServerMember,
) -> Result<(), ServerError> {
    let membership = &member.membership;
    if !member.has_signed_address() {
        return Err(ServerError::Invalid(
            "the server address does not match its key".to_owned(),
        ));
    }
    let device_key = find_device_key(state, &membership.device_id)?;
    verify_server_membership(membership, device_key).map_err(|_| {
        ServerError::Forbidden("the server membership does not verify")
    })
}

pub fn check_term_claim(
    state: &StoredState,
    term: &ServerTerm,
    hosting_member: &ServerMember,
) -> Result<(), ServerError> {
    let is_hosting_device = hosting_member.membership.device_id
        == term.claimed_by
        && hosting_member.membership.server_id == term.server_id;
    if !is_hosting_device {
        return Err(ServerError::Forbidden(
            "the term was not claimed by the device hosting its server",
        ));
    }
    let device_key = find_device_key(state, &term.claimed_by)?;
    verify_server_term(term, device_key)
        .map_err(|_| ServerError::Forbidden("the server term does not verify"))
}

pub fn check_group(state: &StoredState) -> Result<(), ServerError> {
    let group = &state.server_group;
    let term = group.term.as_ref().ok_or_else(|| {
        ServerError::Invalid("the copy has no server term".to_owned())
    })?;
    let hosting_member =
        group.find_member(&term.server_id).ok_or_else(|| {
            ServerError::Invalid(
                "the term's server is not a member".to_owned(),
            )
        })?;
    check_term_claim(state, term, hosting_member)?;
    for member in &group.members {
        check_member(state, member)?;
    }
    Ok(())
}

fn find_device_key<'state>(
    state: &'state StoredState,
    device_id: &DeviceId,
) -> Result<&'state [u8], ServerError> {
    state
        .devices
        .get(device_id)
        .map(|device| device.signing_public_key.as_slice())
        .ok_or(ServerError::NotFound("the device"))
}

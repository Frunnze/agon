use orchestration_api::updates::ChangeTopic;
use orchestration_core::device::{Device, DeviceRole};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::{
    ServerGroup, ServerMember, ServerTerm,
};

use crate::change::Change;
use crate::device_registration::name_device;
use crate::error::ServerError;
use crate::server_group_trust::{check_member, check_term_claim};
use crate::stored_state::StoredState;

const FOUNDING_TERM_NUMBER: u64 = 1;

pub fn found_group(
    state: &mut StoredState,
    founder: &ServerMember,
    term: &ServerTerm,
    server_id: &DeviceId,
) -> Result<Change<ServerGroup>, ServerError> {
    if state.server_group.term.is_some() {
        return Err(ServerError::Conflict(
            "the app server group already exists".to_owned(),
        ));
    }
    let is_this_server = &founder.membership.server_id == server_id
        && &term.server_id == server_id
        && term.number == FOUNDING_TERM_NUMBER;
    if !is_this_server {
        return Err(ServerError::Invalid(
            "the group must be founded by this app server in term 1"
                .to_owned(),
        ));
    }
    let founder_name = trusted_client(state, &founder.membership.device_id)?
        .name
        .clone();
    check_member(state, founder)?;
    check_term_claim(state, term, founder)?;

    let group = &mut state.server_group;
    group.term = Some(term.clone());
    group.members = vec![founder.clone()];
    add_audit_signer(group, founder);
    let event_text = format!("{founder_name} hosts the active app server");
    Ok(Change::recorded(
        group.clone(),
        ChangeTopic::ServerGroup,
        event_text,
    ))
}

pub fn admit_member(
    state: &mut StoredState,
    caller: &DeviceId,
    member: &ServerMember,
) -> Result<Change<ServerGroup>, ServerError> {
    if state.server_group.term.is_none() {
        return Err(ServerError::Conflict(
            "the app server keeps no backups".to_owned(),
        ));
    }
    if &member.membership.device_id != caller {
        return Err(ServerError::Forbidden(
            "a device can only add its own app server",
        ));
    }
    let device_name = trusted_client(state, caller)?.name.clone();
    check_member(state, member)?;
    let owner_of_server = state
        .server_group
        .find_member(&member.membership.server_id)
        .map(|existing| existing.membership.device_id.clone());
    if owner_of_server.is_some_and(|owner| &owner != caller) {
        return Err(ServerError::Conflict(
            "the app server belongs to another device".to_owned(),
        ));
    }

    let group = &mut state.server_group;
    let existing_index = group
        .members
        .iter()
        .position(|existing| &existing.membership.device_id == caller);
    let event_text = if let Some(index) = existing_index {
        replace_member(group, index, member, &device_name)?
    } else {
        group.members.push(member.clone());
        Some(format!("{device_name} keeps a backup of the app server"))
    };
    let Some(event_text) = event_text else {
        return Ok(Change::unchanged(group.clone()));
    };
    add_audit_signer(group, member);
    Ok(Change::recorded(
        group.clone(),
        ChangeTopic::ServerGroup,
        event_text,
    ))
}

pub fn remove_member(
    state: &mut StoredState,
    caller: &DeviceId,
    device_id: &DeviceId,
) -> Result<Change<ServerGroup>, ServerError> {
    if caller != device_id {
        return Err(ServerError::Forbidden(
            "a device can only remove its own app server",
        ));
    }
    let member = state
        .server_group
        .find_member_of_device(device_id)
        .ok_or(ServerError::NotFound("the app server of the device"))?;
    let server_id = member.membership.server_id.clone();
    if state.server_group.active_server_id() == Some(&server_id) {
        return Err(ServerError::Conflict(
            "this device is the active app server".to_owned(),
        ));
    }
    let device_name = name_device(state, device_id);
    let group = &mut state.server_group;
    group
        .members
        .retain(|kept| &kept.membership.device_id != device_id);
    let event_text =
        format!("{device_name} no longer keeps a backup of the app server");
    Ok(Change::recorded(
        group.clone(),
        ChangeTopic::ServerGroup,
        event_text,
    ))
}

pub fn remove_revoked_member(state: &mut StoredState, device_id: &DeviceId) {
    let active_server_id = state.server_group.active_server_id().cloned();
    state.server_group.members.retain(|kept| {
        let is_revoked_device = &kept.membership.device_id == device_id;
        let is_active =
            Some(&kept.membership.server_id) == active_server_id.as_ref();
        !is_revoked_device || is_active
    });
}

pub fn record_takeover(
    state: &mut StoredState,
    term: &ServerTerm,
    server_id: &DeviceId,
) -> Result<Change<ServerGroup>, ServerError> {
    if &term.server_id != server_id {
        return Err(ServerError::Invalid(
            "an app server can only take over for itself".to_owned(),
        ));
    }
    let outranks_current = match &state.server_group.term {
        Some(current) => term.outranks(current),
        None => false,
    };
    if !outranks_current {
        return Err(ServerError::Conflict(
            "the new term must be higher than the current one".to_owned(),
        ));
    }
    let hosting_member = state
        .server_group
        .find_member(server_id)
        .ok_or(ServerError::NotFound("the app server's membership"))?;
    check_term_claim(state, term, hosting_member)?;

    state.server_group.term = Some(term.clone());
    let event_text =
        format!("Took over as the active app server (term {})", term.number);
    Ok(Change::recorded(
        state.server_group.clone(),
        ChangeTopic::ServerGroup,
        event_text,
    ))
}

fn replace_member(
    group: &mut ServerGroup,
    index: usize,
    member: &ServerMember,
    device_name: &str,
) -> Result<Option<String>, ServerError> {
    let active_server_id = group.active_server_id().cloned();
    let Some(existing) = group.members.get_mut(index) else {
        return Err(ServerError::Internal("the member index is stale"));
    };
    if existing.membership == member.membership {
        if existing.address == member.address {
            return Ok(None);
        }
        existing.address = member.address.clone();
        let event_text =
            format!("Updated the address of {device_name}'s app server");
        return Ok(Some(event_text));
    }
    if Some(&existing.membership.server_id) == active_server_id.as_ref() {
        return Err(ServerError::Conflict(
            "this device is the active app server".to_owned(),
        ));
    }
    *existing = member.clone();
    Ok(Some(format!(
        "{device_name} keeps a new backup of the app server"
    )))
}

fn add_audit_signer(group: &mut ServerGroup, member: &ServerMember) {
    let membership = &member.membership;
    group.audit_signers.insert(
        membership.server_id.clone(),
        membership.server_signing_public_key.clone(),
    );
}

fn trusted_client<'state>(
    state: &'state StoredState,
    device_id: &DeviceId,
) -> Result<&'state Device, ServerError> {
    let device = state
        .devices
        .get(device_id)
        .ok_or(ServerError::NotFound("the device"))?;
    if device.revoked {
        return Err(ServerError::Forbidden("the device has been revoked"));
    }
    if device.role == DeviceRole::Runner {
        return Err(ServerError::Forbidden(
            "only a client device can keep a backup of the app server",
        ));
    }
    Ok(device)
}

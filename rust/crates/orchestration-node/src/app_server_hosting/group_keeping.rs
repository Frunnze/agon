mod keeper_loop;
mod keeper_signals;
mod member_links;

use chrono::Utc;
use orchestration_core::server_group::ServerMember;
use orchestration_p2p::service_endpoint::ServiceEndpoint;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::server_group::{
    ServerKeys, sign_server_membership, sign_server_term,
};

pub(super) use keeper_signals::{
    describe_own_address, describe_server_problem,
};

use super::HostedAppServer;
use crate::node::Node;
use crate::node_error::NodeError;
use keeper_loop::{KeeperContext, keep_group};

const FOUNDING_TERM_NUMBER: u64 = 1;

pub(crate) fn keep_server_group(node: &Node) -> Result<(), NodeError> {
    let Some(identity) = node.find_identity()? else {
        return Ok(());
    };
    let mut hosted_slot = node.lock_hosted_app_server();
    let Some(hosted) = hosted_slot.as_mut() else {
        return Ok(());
    };
    if !hosted.is_keeping() {
        found_group_if_missing(hosted, &identity)?;
        let hosted_view = hosted
            .server()
            .describe_group()
            .map_err(|problem| describe_server_problem(&problem))?;
        node.device_files().save_server_group(&hosted_view.group)?;
        let context = KeeperContext {
            server: hosted.server(),
            endpoint: hosted.endpoint(),
            identity,
            dialer: node.shared_server_dialer(),
            takeover_after: node.takeover_after(),
        };
        hosted.attach_keeping(tokio::spawn(keep_group(context)));
    }
    drop(hosted_slot);
    node.reconnect_app_server()
}

pub(super) fn sign_own_member(
    identity: &DeviceIdentity,
    endpoint: &ServiceEndpoint,
    server_signing_public_key: Vec<u8>,
) -> ServerMember {
    let address = describe_own_address(endpoint);
    let server_keys = ServerKeys {
        signing_public_key: server_signing_public_key,
        endpoint_public_key: address.endpoint_public_key,
    };
    ServerMember {
        membership: sign_server_membership(identity, &server_keys, Utc::now()),
        address,
    }
}

fn found_group_if_missing(
    hosted: &HostedAppServer,
    identity: &DeviceIdentity,
) -> Result<(), NodeError> {
    let server = hosted.server();
    let device_id = identity.device_id();
    let needs_founding = server
        .read(|state| {
            let has_group = state.server_group.term.is_some();
            Ok(!has_group && state.devices.contains_key(&device_id))
        })
        .map_err(|problem| describe_server_problem(&problem))?;
    if !needs_founding {
        return Ok(());
    }
    let server_key = server.public_identity().signing_public_key;
    let founder = sign_own_member(identity, &hosted.endpoint(), server_key);
    let term =
        sign_server_term(identity, FOUNDING_TERM_NUMBER, server.device_id());
    server
        .found_group(&founder, &term)
        .map_err(|problem| describe_server_problem(&problem))?;
    Ok(())
}

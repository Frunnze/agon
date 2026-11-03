use orchestration_core::device::{Device, DeviceRole, HardwareKeyKind};
use orchestration_core::identifiers::{ProjectId, WorkspaceId};
use orchestration_core::peer_address::PeerAddress;
use orchestration_core::workspace::{AgentAccess, Project, Repository};
use orchestration_node::live_link_messages::RepositoryReference;
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH,
};
use orchestration_security::peer_addresses::sign_peer_address;
use proptest::prelude::*;
use uuid::Uuid;

use super::entity_strategies::sample_time;

pub const ADDRESS: &str = "github.com/acme/app";
pub const READER_KEY: [u8; 32] = [42; 32];

#[derive(Clone, Copy, Debug)]
pub struct ReaderShape {
    pub role: DeviceRole,
    pub revoked: bool,
    pub in_workspace: bool,
    pub signs_address: bool,
}

fn workspace() -> WorkspaceId {
    WorkspaceId(Uuid::from_u128(7))
}

pub fn project() -> Project {
    Project {
        id: ProjectId(Uuid::from_u128(9)),
        workspace_id: workspace(),
        name: "acme-app".to_owned(),
        repositories: vec![Repository {
            address: ADDRESS.to_owned(),
            default_branch: "main".to_owned(),
            agent_access: AgentAccess::ReadOnly,
        }],
    }
}

pub fn build_device(shape: ReaderShape, seed: u8) -> Result<Device, String> {
    let secret = [seed; IDENTITY_SECRET_LENGTH];
    let identity = DeviceIdentity::from_secret_bytes(&secret)
        .map_err(|problem| problem.to_string())?;
    let address = PeerAddress {
        endpoint_public_key: READER_KEY,
        direct_addresses: Vec::new(),
        relay_url: None,
    };
    let mut signed = sign_peer_address(&identity, &address, sample_time());
    if !shape.signs_address {
        signed.signature = vec![0; signed.signature.len()];
    }
    let public = identity.public_identity();
    let workspaces = if shape.in_workspace {
        vec![workspace()]
    } else {
        Vec::new()
    };
    Ok(Device {
        id: public.device_id,
        name: "laptop".to_owned(),
        role: shape.role,
        key_kind: HardwareKeyKind::Software,
        signing_public_key: public.signing_public_key,
        sealing_public_key: public.sealing_public_key,
        workspaces,
        paired_at: sample_time(),
        approved_by: None,
        last_seen: sample_time(),
        revoked: shape.revoked,
        peer_address: Some(signed),
    })
}

pub fn reader_shape() -> impl Strategy<Value = ReaderShape> {
    let role = prop_oneof![
        Just(DeviceRole::Client),
        Just(DeviceRole::Runner),
        Just(DeviceRole::ClientAndRunner),
    ];
    (role, any::<bool>(), any::<bool>(), any::<bool>()).prop_map(
        |(role, revoked, in_workspace, signs_address)| ReaderShape {
            role,
            revoked,
            in_workspace,
            signs_address,
        },
    )
}

pub fn reference(address: &str) -> RepositoryReference {
    RepositoryReference {
        project_id: project().id,
        address: address.to_owned(),
    }
}
